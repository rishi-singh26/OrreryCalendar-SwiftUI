//
//  ScrubTimelineView.swift
//  Orrery
//
//  Horizontal date scroller (spec §5): a view-aligned, snap-to-day scroll row of tick
//  marks, one per UTC calendar day between `minDate` and `maxDate`, plus a taller tick
//  on the 1st of each month. The tick(s) nearest the centered selection grow tall and
//  turn brass; the rest sit short and dim, month-start ticks a little taller/brighter
//  than the plain days around them. This mirrors the ScrollView-based tick-picker
//  pattern validated in
//  TesterApp's `TickPicker` (see that file's comments for why each scroll/animation
//  piece is shaped the way it is) — same `LazyHStack` + view-aligned `ScrollView` +
//  `animationRange` fade, just keyed by `Date` instead of a raw `Int` selection.
//
//  Performance note: which ticks are month-starts is precomputed once into
//  `monthStartIndices` (recomputed only when `minDate`/`maxDate` change), by walking
//  month-by-month rather than day-by-day — a handful of `Calendar` calls regardless of
//  how many days are in range. Per-tick rendering then does a plain `Set` lookup, no
//  `Calendar` work, so it stays cheap for the dozens of ticks the `LazyHStack` actually
//  renders on every scroll-driven redraw. The day-offset/`Date` conversions and the
//  month-start walk themselves live in `ScrubTimelineMath`, shared with
//  `ScrubTimelineNoAnimationView` since they're identical in both.
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

    @State private var scrollIndex: Int = 0
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var animationRange: ClosedRange<Int> = 0...0
    @State private var isInitialSetupDone = false

    /// Width available to lay the row out in — measured via `.onGeometryChange`
    /// rather than wrapping the `ScrollView` in a `GeometryReader` (which greedily
    /// claims all proposed space and adds a separate layout pass of its own).
    @State private var containerWidth: CGFloat = 0

    /// Tick indices (day offsets from `minDate`) that fall on the 1st of a month —
    /// precomputed once (see performance note above) rather than checked per-tick with
    /// `Calendar`.
    @State private var monthStartIndices: Set<Int> = []

    /// Bumped when scrolling steps `selectedDate` across the 1st of a month — not on
    /// every day, and not on changes made elsewhere — `selectedDate` is a `Binding`
    /// also written by the toolbar's "today" button and date picker, so triggering
    /// feedback off it directly would fire haptics for those too. Applied via
    /// `hapticTick(_:)`, which degrades to a no-op on hardware without haptics (e.g. a
    /// Mac with no Force Touch trackpad).
    @State private var hapticTick = 0

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
        // Centering the first/last tick under the selection point.
        .safeAreaPadding(.horizontal, (containerWidth - tickSlotWidth) / 2)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
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

            // Setting up initial scroll position and month-tick lookup
            monthStartIndices = computeMonthStartIndices()
            updateScrollPosition(for: selectedDate)
            // Optional
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
            monthStartIndices = computeMonthStartIndices()
        }
        .onChange(of: maxDate) { oldValue, newValue in
            monthStartIndices = computeMonthStartIndices()
        }
        .hapticTick(hapticTick)
    }

    // Tick View
    @ViewBuilder
    private func tickView(_ index: Int) -> some View {
        let isInside = animationRange.contains(index)
        let isMonthStart = monthStartIndices.contains(index)
        let fillColor = isInside ? theme.brass : theme.ink.opacity(isMonthStart ? 0.6 : 0.35)
        let heightProgress: CGFloat = isInside ? 1 : (isMonthStart ? majorHeightProgress : minorHeightProgress)

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
        let previous = selectedDate
        selectedDate = candidate
        if ScrubTimelineMath.crossesMonthBoundary(from: previous, to: candidate) {
            hapticTick += 1
        }
    }

    private func index(for date: Date) -> Int {
        ScrubTimelineMath.index(for: date, minDate: minDate, dayCount: dayCount)
    }

    private func date(forIndex index: Int) -> Date {
        ScrubTimelineMath.date(forIndex: index, minDate: minDate)
    }

    private func computeMonthStartIndices() -> Set<Int> {
        ScrubTimelineMath.monthStartIndices(minDate: minDate, maxDate: maxDate)
    }
}
