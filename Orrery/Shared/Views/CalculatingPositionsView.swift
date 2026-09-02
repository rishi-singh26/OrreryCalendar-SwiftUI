//
//  CalculatingPositionsView.swift
//  Orrery
//
//  Shown by `SmallScreenView`/`LargeScreenView` in place of the orrery while
//  `DataController` computes/loads its initial cached range.
//

import SwiftUI

struct CalculatingPositionsView: View {
    var theme: ThemeColors

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(theme.brass)
            Text("Calculating planetary positions…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
