//
//  ScrubTimelineMath.swift
//  Orrery
//
//  Pure day-offset/`Date` math shared by `ScrubTimelineView` and
//  `ScrubTimelineNoAnimationView` — identical in both, since they only differ in
//  how a tick's height/color animates, not in how ticks map to dates. Extracted
//  here (rather than duplicated per-view) to keep that shared math in one place.
//

import Foundation

enum ScrubTimelineMath {
    /// Whole UTC days spanned by `minDate...maxDate`, clamped to be non-negative.
    static func dayCount(minDate: Date, maxDate: Date) -> Int {
        max((try? UTCDay.dayCount(from: minDate, to: maxDate)) ?? 0, 0)
    }

    /// Day-offset index for `date` relative to `minDate`, clamped to `0...dayCount`.
    static func index(for date: Date, minDate: Date, dayCount: Int) -> Int {
        let days = (try? UTCDay.dayCount(from: minDate, to: date)) ?? 0
        return max(min(days, dayCount), 0)
    }

    /// The `Date` `index` whole days after `minDate`.
    static func date(forIndex index: Int, minDate: Date) -> Date {
        UTCDay.calendar.date(byAdding: .day, value: index, to: minDate) ?? minDate
    }

    /// All tick indices (day offsets from `minDate`) that land on the 1st of a
    /// month, found by stepping a cursor month-by-month across `minDate...maxDate`
    /// — a few hundred `Calendar` calls at most, regardless of the day-count of
    /// the range — rather than testing every single day.
    static func monthStartIndices(minDate: Date, maxDate: Date) -> Set<Int> {
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

    /// Whether stepping from `previous` to `next` (in either direction) passes over
    /// the 1st of a month, checked day by day since a single scroll step can span
    /// more than one day. `previous` itself is not checked — its tick, if any,
    /// already triggered feedback when the timeline first landed on it.
    static func crossesMonthBoundary(from previous: Date, to next: Date) -> Bool {
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
