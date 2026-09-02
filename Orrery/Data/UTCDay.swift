//
//  UTCDay.swift
//  Orrery
//
//  All stored planet/moon data is keyed by UTC calendar date (spec §4), so a given
//  index is deterministic regardless of the device's time zone. Every place that needs
//  day-count arithmetic or "what calendar day is this" goes through this type, and
//  always via `Calendar`, never manual 365-day-per-year math, so leap years fall out
//  correctly for free.
//

import Foundation

nonisolated enum UTCDay {
    /// Gregorian calendar fixed to UTC — the single source of truth for day-keying.
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// The UTC-midnight instant for the UTC calendar day containing `date`.
    static func midnight(of date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: comps) ?? date
    }

    /// Whole UTC calendar days from `start` to `end` (both are UTC-midnight-normalized
    /// first, so callers don't have to remember to do it themselves).
    static func dayCount(from start: Date, to end: Date) throws -> Int {
        let s = midnight(of: start)
        let e = midnight(of: end)
        guard let days = calendar.dateComponents([.day], from: s, to: e).day else {
            throw DataLayerError(message: "could not compute day count from \(s) to \(e)")
        }
        return days
    }

    /// One UTC calendar day after `date` (UTC-midnight-normalized).
    static func nextDay(after date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: midnight(of: date)) ?? date
    }

    /// One UTC calendar day before `date` (UTC-midnight-normalized).
    static func previousDay(before date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: midnight(of: date)) ?? date
    }

    /// "Today" resolved from the *device's local* calendar day, then mapped onto the
    /// UTC-keyed index space stored data uses. This is deliberately not the same as
    /// `midnight(of: Date())` — a user in e.g. UTC+13 or UTC-11 must see "today" match
    /// their physical wall calendar, not whatever UTC's date happens to be right now.
    static func todayAsUTCMidnight(deviceCalendar: Calendar = .current) -> Date {
        let local = deviceCalendar.dateComponents([.year, .month, .day], from: Date())
        var utcComponents = DateComponents()
        utcComponents.year = local.year
        utcComponents.month = local.month
        utcComponents.day = local.day
        return calendar.date(from: utcComponents) ?? midnight(of: Date())
    }
}
