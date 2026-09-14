//
//  ScrubTimelineView.swift
//  Orrery
//
//  Horizontal date scroller (spec §5): a view-aligned, snap-to-day scroll row of tick
//  marks, one per UTC calendar day between `minDate` and `maxDate`, plus a taller
//  "boundary" tick at whatever cadence the user has chosen in Settings — Weekly, Every
//  10/15 Days, or Monthly (see `BoundaryTickFrequency`). The tick(s) nearest the centered
//  selection grow tall and turn brass; the rest sit short and dim, boundary ticks a
//  little taller/brighter than the plain days around them. This mirrors the
//  ScrollView-based tick-picker pattern validated in
//  TesterApp's `TickPicker` (see that file's comments for why each scroll/animation
//  piece is shaped the way it is) — same `LazyHStack` + view-aligned `ScrollView` +
//  `animationRange` fade, just keyed by `Date` instead of a raw `Int` selection.
//
//  Performance note: which ticks are boundary ticks is precomputed once into
//  `boundaryIndices` (recomputed when `minDate`/`maxDate`/`boundaryTickFrequency`
//  change), by walking period-by-period rather than day-by-day — a handful of
//  `Calendar` calls regardless of how many days are in range. Per-tick rendering then
//  does a plain `Set` lookup, no `Calendar` work, so it stays cheap for the dozens of
//  ticks the `LazyHStack` actually renders on every scroll-driven redraw. The
//  day-offset/`Date` conversions and the boundary walks themselves live in
//  `ScrubTimelineMath`, shared with `ScrubTimelineNoAnimationView` since they're
//  identical in both.
//
//  Scrolling is handled entirely by the native `ScrollView` (trackpad, mouse wheel, and
//  touch all work out of the box on both platforms), so `selectedDate` is updated
//  continuously as the scroll gesture progresses, not just when it ends.
//

import SwiftUI

struct ScrubTimelineView: View {
    @Binding var selectedDate: Date
    let minDate: Date
    let maxDate: Date
    let theme: ThemeColors

    private let tickWidth: CGFloat = 2
    private let tickHeight: CGFloat = 30
    private let tickHPadding: CGFloat = 3
    private let minorHeightProgress: CGFloat = 0.55
    private let majorHeightProgress: CGFloat = 0.85
    private let interactionHeight: CGFloat = 64
    private let animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)

    /// User-facing cadence for boundary ticks (see `BoundaryTickFrequency`), persisted
    /// across launches. Declared directly on this view — rather than threaded in via
    /// `init` — since it's only ever consumed here and in
    /// `ScrubTimelineNoAnimationView`, matching this app's convention of declaring
    /// `@AppStorage` directly on whichever view(s) actually need a setting.
    @AppStorage(AppStorageKeys.boundaryTickFrequency) private var boundaryTickFrequency: BoundaryTickFrequency = .defaultFrequency

    @State private var scrollIndex: Int
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var animationRange: ClosedRange<Int>
    @State private var isInitialSetupDone = false

    /// Width available to lay the row out in — measured via `.onGeometryChange`
    /// rather than wrapping the `ScrollView` in a `GeometryReader` (which greedily
    /// claims all proposed space and adds a separate layout pass of its own).
    @State private var containerWidth: CGFloat = 0

    /// Tick indices (day offsets from `minDate`) that count as a boundary tick under
    /// `boundaryTickFrequency` — precomputed once (see performance note above) rather
    /// than checked per-tick with `Calendar`, and recomputed whenever `minDate`,
    /// `maxDate`, or `boundaryTickFrequency` changes.
    @State private var boundaryIndices: Set<Int>

    /// Bumped when scrolling steps `selectedDate` across a boundary tick — not on
    /// every day, and not on changes made elsewhere — `selectedDate` is a `Binding`
    /// also written by the toolbar's "today" button and date picker, so triggering
    /// feedback off it directly would fire haptics for those too. Applied via
    /// `hapticTick(_:)`, which degrades to a no-op on hardware without haptics (e.g. a
    /// Mac with no Force Touch trackpad).
    @State private var hapticTick = 0

    /// Seeds the scroll position at `selectedDate` synchronously — rather than
    /// leaving `scrollIndex`/`scrollPosition`/`animationRange` at placeholder
    /// defaults for `.task` to correct asynchronously after the first frame — so
    /// the row renders already centered on launch instead of visibly snapping
    /// there a frame or two later. `minDate`/`maxDate`/`selectedDate` are all
    /// already settled by the time this view is ever created (`SmallScreenView`/
    /// `LargeScreenView` only mount it once a snapshot exists), so there's no
    /// need to wait for `.task` to compute this. `BoundaryTickFrequency.persisted`
    /// is used here instead of `self.boundaryTickFrequency` — a struct's custom
    /// `init` can't read a property-wrapper-backed property via `self` until every
    /// stored property is assigned, and `boundaryIndices` (computed from that
    /// frequency) is one of the properties this very initializer is still in the
    /// middle of assigning.
    init(selectedDate: Binding<Date>, minDate: Date, maxDate: Date, theme: ThemeColors) {
        self._selectedDate = selectedDate
        self.minDate = minDate
        self.maxDate = maxDate
        self.theme = theme

        let dayCount = ScrubTimelineMath.dayCount(minDate: minDate, maxDate: maxDate)
        let safeIndex = ScrubTimelineMath.index(for: selectedDate.wrappedValue, minDate: minDate, dayCount: dayCount)
        _scrollIndex = State(initialValue: safeIndex)
        _scrollPosition = State(initialValue: safeIndex)
        _animationRange = State(initialValue: safeIndex...safeIndex)
        _boundaryIndices = State(initialValue: ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: .persisted))
    }

    /// Whole UTC days spanned by `minDate...maxDate`; the row holds `dayCount + 1`
    /// ticks, one per day, inclusive of both ends.
    private var dayCount: Int {
        ScrubTimelineMath.dayCount(minDate: minDate, maxDate: maxDate)
    }

    /// Width one day occupies in the row: the tick itself plus padding on both sides.
    private var tickSlotWidth: CGFloat {
        tickWidth + tickHPadding * 2
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0...dayCount, id: \.self) { index in
                    tickView(index)
                }
            }
            .frame(height: tickHeight)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // Centering the first/last tick under the selection point. Clamped to
        // a minimum of 0 — before `containerWidth` is measured (still 0 on
        // the first layout pass) this would otherwise go negative, which
        // SwiftUI logs as an invalid frame dimension.
        .safeAreaPadding(.horizontal, max((containerWidth - tickSlotWidth) / 2, 0))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
            let isFirstMeasurement = containerWidth == 0 && newWidth > 0
            containerWidth = newWidth
            guard isFirstMeasurement else { return }

            // `scrollPosition` was seeded to `scrollIndex` back in `init`,
            // before `containerWidth` (and the centering `safeAreaPadding`
            // derived from it) was known — the row resolved that initial
            // position against zero (and, before the clamp above, briefly
            // negative) padding, so the selected tick lands off-center once
            // the real padding is known. Reassigning `scrollPosition` to the
            // same index it already holds is a no-op, so clear it first to
            // force the row to re-resolve the anchor now that the padding is
            // correct, then restore it on the next run-loop turn — the same
            // fix `VerticalScrubber` uses for its identical padding-timing
            // issue.
            scrollPosition = nil
            Task { @MainActor in
                scrollPosition = scrollIndex
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.x + $0.contentInsets.leading
        } action: { oldValue, newValue in
            guard scrollPhase != .idle else { return }
            let index = max(min(Int((newValue / tickSlotWidth).rounded()), dayCount), 0)
            let previousScrollIndex = scrollIndex
            scrollIndex = index

            let isGreater = scrollIndex > previousScrollIndex
            let leadingBound = isGreater ? previousScrollIndex : scrollIndex
            let trailingBound = !isGreater ? previousScrollIndex : scrollIndex
            animationRange = leadingBound...trailingBound
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            scrollPhase = newPhase
            animationRange = scrollIndex...scrollIndex

            // In some rare instances the view aligned target behaviour will not
            // center the item; this works it out.
            if newPhase == .idle && scrollPosition != scrollIndex {
                withAnimation(animation) {
                    scrollPosition = scrollIndex
                }
            }
        }
        .frame(height: interactionHeight)
        .task {
            guard !isInitialSetupDone else { return }

            // Initial scroll position and month-tick lookup are seeded synchronously
            // in `init` (see its doc comment) — this just holds interaction off for a
            // beat so the view-aligned scroll target settles before it's hit-testable.
            try? await Task.sleep(for: .seconds(0.05))
            isInitialSetupDone = true
        }
        // Enabling interaction only after the initial setup is done
        .allowsHitTesting(isInitialSetupDone)
        .onChange(of: scrollIndex) { oldValue, newValue in
            Task {
                applySelection(forIndex: newValue)
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            let newIndex = index(for: newValue)
            guard scrollIndex != newIndex else { return }
            updateScrollPosition(for: newValue)
        }
        .onChange(of: minDate) { oldValue, newValue in
            boundaryIndices = computeBoundaryIndices()
        }
        .onChange(of: maxDate) { oldValue, newValue in
            boundaryIndices = computeBoundaryIndices()
        }
        .onChange(of: boundaryTickFrequency) { oldValue, newValue in
            boundaryIndices = computeBoundaryIndices()
        }
        .hapticTick(hapticTick)
    }

    // Tick View
    @ViewBuilder
    private func tickView(_ index: Int) -> some View {
        let isInside = animationRange.contains(index)
        let isBoundary = boundaryIndices.contains(index)
        let fillColor: Color = isInside ? .accentColor : theme.ink.opacity(isBoundary ? 0.6 : 0.35)
        let heightProgress: CGFloat = isInside ? 1 : (isBoundary ? majorHeightProgress : minorHeightProgress)

        Rectangle()
            .fill(fillColor)
            .frame(
                width: tickWidth,
                height: tickHeight * heightProgress
            )
            .frame(width: tickSlotWidth, height: tickHeight, alignment: .bottom)
            .animation(isInside || !isInitialSetupDone ? .none : animation, value: isInside)
    }

    private func updateScrollPosition(for date: Date) {
        let safeIndex = index(for: date)
        scrollPosition = safeIndex
        scrollIndex = safeIndex
        animationRange = safeIndex...safeIndex
    }

    /// Applies a scroll-driven index change to `selectedDate`, clamped implicitly by
    /// the row only ever containing `minDate...maxDate` (index 0...`dayCount`).
    private func applySelection(forIndex newIndex: Int) {
        let candidate = date(forIndex: newIndex)
        guard candidate != selectedDate else { return }
        let previousIndex = index(for: selectedDate)
        selectedDate = candidate
        if ScrubTimelineMath.crossesBoundary(fromIndex: previousIndex, toIndex: newIndex, boundaryIndices: boundaryIndices) {
            hapticTick += 1
        }
    }

    private func index(for date: Date) -> Int {
        ScrubTimelineMath.index(for: date, minDate: minDate, dayCount: dayCount)
    }

    private func date(forIndex index: Int) -> Date {
        ScrubTimelineMath.date(forIndex: index, minDate: minDate)
    }

    private func computeBoundaryIndices() -> Set<Int> {
        ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: boundaryTickFrequency)
    }
}
