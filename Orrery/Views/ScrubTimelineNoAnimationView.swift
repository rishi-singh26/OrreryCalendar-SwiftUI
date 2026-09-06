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
//  Performance note: exactly like `ScrubTimelineView`, month-start tick indices are
//  precomputed once into `monthStartIndices` (recomputed only when `minDate`/`maxDate`
//  change) by walking month-by-month rather than day-by-day, so per-tick rendering is a
//  plain `Set` lookup with no `Calendar` work.
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

    @State private var scrollIndex: Int = 0
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var isInitialSetupDone = false

    /// Tick indices (day offsets from `minDate`) that fall on the 1st of a month —
    /// precomputed once (see performance note above) rather than checked per-tick with
    /// `Calendar`.
    @State private var monthStartIndices: Set<Int> = []

    /// Bumped when scrolling steps `selectedDate` across the 1st of a month — see
    /// `ScrubTimelineView`'s identical property for the full rationale. Applied via
    /// `hapticTick(_:)`, which degrades to a no-op on hardware without haptics (e.g. a
    /// Mac with no Force Touch trackpad).
    @State private var hapticTick = 0

    /// Whole UTC days spanned by `minDate...maxDate`; the row holds `dayCount + 1`
    /// ticks, one per day, inclusive of both ends.
    private var dayCount: Int {
        max((try? UTCDay.dayCount(from: minDate, to: maxDate)) ?? 0, 0)
    }

    /// Width one day occupies in the row: the tick itself plus padding on both sides.
    private var tickSlotWidth: CGFloat {
        tickWidth + tickHPadding * 2
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

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
            .safeAreaPadding(.horizontal, (size.width - tickSlotWidth) / 2)
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

    // Tick View — no animation: height/color reflect the current scroll position
    // directly, every redraw.
    @ViewBuilder
    private func tickView(_ index: Int) -> some View {
        let isSelected = index == scrollIndex
        let isMonthStart = monthStartIndices.contains(index)
        let fillColor = isSelected ? theme.brass : theme.ink.opacity(isMonthStart ? 0.6 : 0.35)
        let heightProgress: CGFloat = isSelected ? 1.2 : (isMonthStart ? majorHeightProgress : minorHeightProgress)

        Rectangle()
            .fill(fillColor)
            .frame(width: tickWidth, height: tickHeight * heightProgress)
            .frame(width: tickSlotWidth, height: tickHeight, alignment: .bottom)
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
        let previous = selectedDate
        selectedDate = candidate
        if crossesMonthBoundary(from: previous, to: candidate) {
            hapticTick += 1
        }
    }

    private func index(for date: Date) -> Int {
        let days = (try? UTCDay.dayCount(from: minDate, to: date)) ?? 0
        return max(min(days, dayCount), 0)
    }

    private func date(forIndex index: Int) -> Date {
        UTCDay.calendar.date(byAdding: .day, value: index, to: minDate) ?? minDate
    }

    /// All tick indices (day offsets from `minDate`) that land on the 1st of a month,
    /// found by stepping a cursor month-by-month across `minDate...maxDate` — a few
    /// hundred `Calendar` calls at most, regardless of the day-count of the range —
    /// rather than testing every single day.
    private func computeMonthStartIndices() -> Set<Int> {
        guard maxDate >= minDate else { return [] }
        let calendar = UTCDay.calendar
        var indices = Set<Int>()
        var cursor = calendar.date(from: calendar.dateComponents([.year, .month], from: minDate)) ?? minDate

        while cursor <= maxDate {
            if cursor >= minDate, let idx = try? UTCDay.dayCount(from: minDate, to: cursor) {
                indices.insert(idx)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return indices
    }

    /// Whether stepping from `previous` to `next` (in either direction) passes over the
    /// 1st of a month, checked day by day since a single scroll step can span more than
    /// one day. `previous` itself is not checked — its tick, if any, already triggered
    /// feedback when the timeline first landed on it.
    private func crossesMonthBoundary(from previous: Date, to next: Date) -> Bool {
        guard let spanDays = try? UTCDay.dayCount(from: previous, to: next), spanDays != 0 else { return false }
        let step = spanDays > 0 ? 1 : -1
        var cursor = previous
        for _ in 0..<abs(spanDays) {
            guard let stepped = UTCDay.calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = stepped
            if UTCDay.calendar.component(.day, from: cursor) == 1 { return true }
        }
        return false
    }
}
