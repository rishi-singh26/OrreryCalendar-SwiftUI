//
//  AutoPlaySettings.swift
//  Orrery
//
//  Persisted settings for the auto play feature (see `AutoPlayController`).
//

import Foundation

/// How fast auto play advances the selected date. Months/years use their average
/// lengths so that playback is a smooth, constant rate of days per second.
enum AutoPlayRate: String, CaseIterable, Identifiable {
    case day1, day2, day3, day4, day5, day6
    case week1, week2, week3
    case month1, month2
//    case month3, month4, month5, month6
//    case month7, month8, month9, month10, month11
//    case year1

    var id: String { rawValue }

    static let defaultRate: AutoPlayRate = .week1

    static let averageDaysPerMonth = 30.436875
    static let averageDaysPerYear = 365.2425

    private enum Unit { case day, week, month, year }

    private var parts: (count: Int, unit: Unit) {
        switch self {
        case .day1: (1, .day)
        case .day2: (2, .day)
        case .day3: (3, .day)
        case .day4: (4, .day)
        case .day5: (5, .day)
        case .day6: (6, .day)
        case .week1: (1, .week)
        case .week2: (2, .week)
        case .week3: (3, .week)
        case .month1: (1, .month)
        case .month2: (2, .month)
        // case .month3: (3, .month)
        // case .month4: (4, .month)
        // case .month5: (5, .month)
        // case .month6: (6, .month)
        // case .month7: (7, .month)
        // case .month8: (8, .month)
        // case .month9: (9, .month)
        // case .month10: (10, .month)
        // case .month11: (11, .month)
        // case .year1: (1, .year)
        }
    }

    var daysPerSecond: Double {
        let (count, unit) = parts
        switch unit {
        case .day: return Double(count)
        case .week: return Double(count) * 7
        case .month: return Double(count) * Self.averageDaysPerMonth
        case .year: return Double(count) * Self.averageDaysPerYear
        }
    }

    var label: String {
        let (count, unit) = parts
        let name: String
        switch unit {
        case .day: name = "Day"
        case .week: name = "Week"
        case .month: name = "Month"
        case .year: name = "Year"
        }
        return "\(count) \(name)\(count == 1 ? "" : "s") / Sec"
    }

    /// Compact form for tight spaces (e.g. "2D", "1W", "1M"); still unique per case.
    var shortLabel: String {
        let (count, unit) = parts
        let suffix: String
        switch unit {
        case .day: suffix = "D"
        case .week: suffix = "W"
        case .month: suffix = "M"
        case .year: suffix = "Y"
        }
        return "\(count)\(suffix)"
    }

    static var persisted: AutoPlayRate {
        UserDefaults.standard.string(forKey: AppStorageKeys.autoPlayRate)
            .flatMap(AutoPlayRate.init(rawValue:)) ?? defaultRate
    }
}

enum AutoPlayDirection: String, CaseIterable, Identifiable {
    case forward, backward

    var id: String { rawValue }
    static let defaultDirection: AutoPlayDirection = .forward

    var sign: Int { self == .forward ? 1 : -1 }
    var label: String { self == .forward ? "Forward" : "Backward" }
    
    var systemImage: String {
        switch self {
        case .forward: return "arrow.forward.circle"
        case .backward: return "arrow.backward.circle"
        }
    }
}

/// What a *discrete* manual date change (date picker, Today, saved item) does to a
/// running auto play. Dragging the scrub timeline always pauses, regardless.
enum AutoPlayManualChangeBehavior: String, CaseIterable, Identifiable {
    case pause, keepPlaying

    var id: String { rawValue }
    static let defaultBehavior: AutoPlayManualChangeBehavior = .pause

    var label: String { self == .pause ? "Pause" : "Keep Playing" }

    static var persisted: AutoPlayManualChangeBehavior {
        UserDefaults.standard.string(forKey: AppStorageKeys.autoPlayManualChange)
            .flatMap(AutoPlayManualChangeBehavior.init(rawValue:)) ?? defaultBehavior
    }
}
