//
//  DateScrubTimeline.swift
//  Orrery
//
//  Picks the scrub timeline variant shared by `SmallScreenView` and `LargeScreenView`.
//  `ScrubTimelineView`'s animated tick fade gets visibly laggy once the cached range spans
//  more than ±10 years (see `ContentViewModel.rangeYearsForAnimatedScrubber`); the
//  no-animation variant trades that fade for scrolling that stays smooth at any range size.
//

import SwiftUI

struct DateScrubTimeline: View {
    @Binding var selectedDate: Date
    let minDate: Date
    let maxDate: Date
    let theme: ThemeColors
    let useAnimatedTicks: Bool

    var body: some View {
        if useAnimatedTicks {
            ScrubTimelineView(selectedDate: $selectedDate, minDate: minDate, maxDate: maxDate, theme: theme)
        } else {
            ScrubTimelineNoAnimationView(selectedDate: $selectedDate, minDate: minDate, maxDate: maxDate, theme: theme)
        }
    }
}
