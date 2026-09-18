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

/// User-facing cadence for the scrub timeline's "boundary" ticks — the ticks that
/// render taller/brighter than plain day ticks and trigger haptic feedback when
/// scrubbed across. Persisted via `@AppStorage(AppStorageKeys.boundaryTickFrequency)`.
enum BoundaryTickFrequency: String, CaseIterable, Identifiable {
    case weekly
    case every10Days
    case every15Days
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .every10Days: return "Every 10 Days"
        case .every15Days: return "Every 15 Days"
        case .monthly: return "Monthly"
        }
    }

    /// The single source of truth for the setting's default — used both as the
    /// `@AppStorage` default (in `ScrubTimelineView`, `ScrubTimelineNoAnimationView`,
    /// and `SettingsPanel`) and as `persisted`'s fallback below, so the two can't drift
    /// apart.
    static let defaultFrequency: BoundaryTickFrequency = .monthly

    /// Reads the persisted frequency straight from `UserDefaults`, bypassing the
    /// `@AppStorage` property-wrapper accessor. Needed in `ScrubTimelineView`'s and
    /// `ScrubTimelineNoAnimationView`'s custom `init`s: a struct's custom initializer
    /// can't read a property-wrapper-backed property via `self` while another stored
    /// property computed from it (`boundaryIndices`) is still being assigned in that
    /// same initializer.
    static var persisted: BoundaryTickFrequency {
        UserDefaults.standard.string(forKey: AppStorageKeys.boundaryTickFrequency)
            .flatMap(BoundaryTickFrequency.init(rawValue:)) ?? defaultFrequency
    }
}

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

    /// All tick indices (day offsets from `minDate`) that count as a "boundary" tick
    /// under `frequency` — the dispatcher `tickView(_:)` and `applySelection(forIndex:)`
    /// go through, so rendering and haptics always agree on the same set of indices.
    static func boundaryIndices(minDate: Date, maxDate: Date, frequency: BoundaryTickFrequency) -> Set<Int> {
        switch frequency {
        case .monthly:
            return monthStartIndices(minDate: minDate, maxDate: maxDate)
        case .weekly:
            return weekStartIndices(minDate: minDate, maxDate: maxDate)
        case .every10Days:
            return fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 10)
        case .every15Days:
            return fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 15)
        }
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

    /// All tick indices (day offsets from `minDate`) that land on a calendar week
    /// start (`UTCDay.calendar.firstWeekday`, always Sunday since that calendar is
    /// locale-independent). Unlike `monthStartIndices` (months vary in length, so that
    /// walk genuinely needs a `Calendar` call per month), weeks are a fixed 7-day span:
    /// a single `Calendar` lookup finds the offset of the first week-start on or after
    /// `minDate`, and every subsequent one is just `+7` from there — no `Calendar` call
    /// per period, so this stays cheap even across a 100-year range.
    static func weekStartIndices(minDate: Date, maxDate: Date) -> Set<Int> {
        guard maxDate >= minDate else { return [] }
        let calendar = UTCDay.calendar
        // Falls back to treating `minDate` itself as the anchor (degrading to an
        // every-7-days-from-`minDate` grid, like `fixedCadenceIndices`) on the
        // practically-unreachable case where either `Calendar` call fails, rather than
        // giving up on boundary ticks entirely.
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: minDate)?.start ?? minDate
        let offsetIntoWeek = (try? UTCDay.dayCount(from: weekStart, to: minDate)) ?? 0
        let firstIndex = offsetIntoWeek == 0 ? 0 : 7 - offsetIntoWeek
        let totalDays = dayCount(minDate: minDate, maxDate: maxDate)

        var indices = Set<Int>()
        var index = firstIndex
        while index <= totalDays {
            indices.insert(index)
            index += 7
        }
        return indices
    }

    /// All tick indices (day offsets from `minDate`) on a fixed `intervalDays` cadence
    /// counted from `minDate` itself (index `0`, always a boundary) — used for cadences
    /// with no natural calendar unit (e.g. every 10 or 15 days), so unlike
    /// `monthStartIndices`/`weekStartIndices` this cadence is anchored to the visible
    /// range's start rather than a calendar-fixed point, and shifts if `minDate` does.
    static func fixedCadenceIndices(minDate: Date, maxDate: Date, intervalDays: Int) -> Set<Int> {
        guard maxDate >= minDate, intervalDays > 0 else { return [] }
        let dayCount = dayCount(minDate: minDate, maxDate: maxDate)
        var indices = Set<Int>()
        var index = 0
        while index <= dayCount {
            indices.insert(index)
            index += intervalDays
        }
        return indices
    }

    /// Whether stepping from `fromIndex` to `toIndex` (in either direction) passes
    /// over a boundary tick, per the already-computed `boundaryIndices`. `fromIndex`
    /// itself is not checked — its tick, if any, already triggered feedback when the
    /// timeline first landed on it — `toIndex` is checked, so a single scroll step
    /// spanning more than one day still catches every boundary along the way.
    static func crossesBoundary(fromIndex: Int, toIndex: Int, boundaryIndices: Set<Int>) -> Bool {
        guard fromIndex != toIndex else { return false }
        let range = fromIndex < toIndex ? (fromIndex + 1)...toIndex : toIndex...(fromIndex - 1)
        return range.contains { boundaryIndices.contains($0) }
    }
}
