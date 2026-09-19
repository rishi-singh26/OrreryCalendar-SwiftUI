//
//  ScrubTimelineNoAnimationView.swift
//  Orrery
//
//  A no-animation take on the scrub timeline (see `ScrubTimelineView`, which this
//  mirrors structurally). `ScrubTimelineView`'s animated, range-based fade between tick
//  states gets visibly laggy once the cached range spans more than ±10 years (tens of
//  thousands of ticks scrolling past) — ticks here just snap straight to whatever
//  height/color the current scroll position calls for, no `Animation` ever applied, so
//  there's no per-tick fade to fall behind on. That also means there's no need for the
//  animated view's `animationRange` (the span of ticks a fade animates across): only the
//  exact tick under the current selection needs to look different from the rest.
//  `LargeScreenView`/`SmallScreenView` pick between the two based on the selected range,
//  not the platform — a large range scrolled from a trackpad or touch is equally likely
//  to lag with the animated version.
//
//  Performance note: exactly like `ScrubTimelineView`, boundary tick indices (whatever
//  cadence — Weekly, Every 10/15 Days, or Monthly — the user has chosen in Settings; see
//  `BoundaryTickFrequency`) are precomputed once into `boundaryIndices` (recomputed when
//  `minDate`/`maxDate`/`boundaryTickFrequency` change) by walking period-by-period rather
//  than day-by-day, so per-tick rendering is a plain `Set` lookup with no `Calendar`
//  work. The day-offset/`Date` conversions and the boundary walks themselves live in
//  `ScrubTimelineMath`, shared with `ScrubTimelineView` since they're identical in both.
//
//  `selectedDate` is updated continuously as the scroll gesture progresses (not just
//  when it ends), so the chart tracks the timeline live.
//

import SwiftUI

struct ScrubTimelineNoAnimationView: View {
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

    /// User-facing cadence for boundary ticks (see `BoundaryTickFrequency`), persisted
    /// across launches. Declared directly on this view — rather than threaded in via
    /// `init` — since it's only ever consumed here and in `ScrubTimelineView`, matching
    /// this app's convention of declaring `@AppStorage` directly on whichever view(s)
    /// actually need a setting.
    @AppStorage(AppStorageKeys.boundaryTickFrequency) private var boundaryTickFrequency: BoundaryTickFrequency = .defaultFrequency

    @State private var scrollIndex: Int
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
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

    /// Bumped when scrolling steps `selectedDate` across a boundary tick — see
    /// `ScrubTimelineView`'s identical property for the full rationale. Applied via
    /// `hapticTick(_:)`, which degrades to a no-op on hardware without haptics (e.g. a
    /// Mac with no Force Touch trackpad).
    @State private var hapticTick = 0

    /// Seeds the scroll position at `selectedDate` synchronously — rather than
    /// leaving `scrollIndex`/`scrollPosition` at placeholder defaults for `.task`
    /// to correct asynchronously after the first frame — so the row renders
    /// already centered on launch instead of visibly snapping there a frame or
    /// two later. `minDate`/`maxDate`/`selectedDate` are all already settled by
    /// the time this view is ever created (`SmallScreenView`/`LargeScreenView`
    /// only mount it once a snapshot exists), so there's no need to wait for
    /// `.task` to compute this. `BoundaryTickFrequency.persisted` is used here
    /// instead of `self.boundaryTickFrequency` — a struct's custom `init` can't
    /// read a property-wrapper-backed property via `self` until every stored
    /// property is assigned, and `boundaryIndices` (computed from that frequency)
    /// is one of the properties this very initializer is still in the middle of
    /// assigning.
    init(selectedDate: Binding<Date>, minDate: Date, maxDate: Date, theme: ThemeColors) {
        self._selectedDate = selectedDate
        self.minDate = minDate
        self.maxDate = maxDate
        self.theme = theme

        let dayCount = ScrubTimelineMath.dayCount(minDate: minDate, maxDate: maxDate)
        let safeIndex = ScrubTimelineMath.index(for: selectedDate.wrappedValue, minDate: minDate, dayCount: dayCount)
        _scrollIndex = State(initialValue: safeIndex)
        _scrollPosition = State(initialValue: safeIndex)
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
                    let isBoundary = boundaryIndices.contains(index)
                    let fillColor = theme.ink.opacity(isBoundary ? 0.6 : 0.35)
                    let heightProgress: CGFloat = isBoundary ? majorHeightProgress : minorHeightProgress
                    Rectangle()
                        .fill(fillColor)
                        .frame(width: tickWidth, height: tickHeight * heightProgress)
                        .frame(width: tickSlotWidth, height: tickHeight, alignment: .bottom)
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
        // Static marker at the viewport's center — the point the view-aligned
        // scroll behavior snaps the selected tick to (mirrors WheelPicker's
        // center indicator).
        .overlay(alignment: .center) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: tickWidth, height: tickHeight)
        }
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
            scrollIndex = max(min(Int((newValue / tickSlotWidth).rounded()), dayCount), 0)
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            scrollPhase = newPhase

            // In some rare instances the view aligned target behaviour will not
            // center the item; this works it out.
            if newPhase == .idle && scrollPosition != scrollIndex {
                scrollPosition = scrollIndex
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

    private func updateScrollPosition(for date: Date) {
        let safeIndex = index(for: date)
        scrollPosition = safeIndex
        scrollIndex = safeIndex
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
