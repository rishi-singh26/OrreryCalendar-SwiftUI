//
//  ExtendRangeButton.swift
//  Orrery
//
//  Surfaced by `SmallScreenView`/`LargeScreenView` once the selected date is within 30
//  days of the cached range's edge — see `ContentViewModel.isNearRangeEdge`.
//

import SwiftUI

struct ExtendRangeButton: View {
    var theme: ThemeColors
    var action: () -> Void

    var body: some View {
        Button("Extend the cached range in Settings", action: action)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(theme.brass)
    }
}
