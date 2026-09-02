//
//  SelectedDateTitleText.swift
//  Orrery
//
//  The serif title date shown atop LargeScreenView/SmallScreenView's chart and in the
//  PolaroidShareView caption — one formatter and one Text style shared across all
//  three, so they can't drift apart (e.g. "Thu, 3 Sep 2026").
//
//  `date` is always a UTC-midnight instant (see `UTCDay`), so the formatter is fixed
//  to the UTC time zone — matching `ScrubTimelineView`'s tick-label formatter — rather
//  than the device's local time zone. That guarantees the weekday shown here always
//  agrees with the day/month/year also shown here, and both always agree with the
//  calendar day `date` actually represents, regardless of the device's time zone.
//  Locale is likewise fixed to `en_US_POSIX` so the month/weekday abbreviations and
//  digits render the same on every device, independent of the user's language/region
//  settings.
//

import SwiftUI

struct SelectedDateTitleText: View {
    let date: Date
    let color: Color

    var body: some View {
        Text(Self.string(from: date))
            .font(.system(.title, design: .serif))
            .foregroundStyle(color)
    }

    /// The plain formatted string, for callers that need text rather than a `View` —
    /// e.g. `PolaroidShareButton`'s `SharePreview` caption.
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM y"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
