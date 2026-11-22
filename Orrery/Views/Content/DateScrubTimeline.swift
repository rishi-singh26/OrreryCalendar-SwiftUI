//
//  DateScrubTimeline.swift
//  Orrery
//
//  Picks the scrub timeline variant shared by `SmallScreenView` and `LargeScreenView`.
//  `ScrubTimelineView`'s animated tick fade gets visibly laggy once the cached range spans
//  more than ±`maxRangeYearsForAnimatedTicks` years; the no-animation variant trades that
//  fade for scrolling that stays smooth at any range size.
//

import SwiftUI

struct DateScrubTimeline: View {
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    /// Largest cached range, in years either side of today (±), for which the animated tick
    /// fade is still smooth. Compared against the `rangeYears` setting.
    private static let maxRangeYearsForAnimatedTicks = 20

    @Binding var selectedDate: Date
    let minDate: Date
    let maxDate: Date
    let theme: ThemeColors

    var body: some View {
        if rangeYears > Self.maxRangeYearsForAnimatedTicks {
            ScrubTimelineNoAnimationView(selectedDate: $selectedDate, minDate: minDate, maxDate: maxDate, theme: theme)
        } else {
            ScrubTimelineView(selectedDate: $selectedDate, minDate: minDate, maxDate: maxDate, theme: theme)
        }
    }
}
