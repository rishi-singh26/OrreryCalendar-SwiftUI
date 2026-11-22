//
//  AutoPlaySpeedNotch.swift
//  Orrery
//
//  The trailing-edge Auto Play speed control docked in a wedged notch, shared by
//  `SmallScreenView` and `LargeScreenView`. Placement (padding/frame/offset) is left to
//  each caller since it differs per layout.
//

import SwiftUI

struct AutoPlaySpeedNotch: View {
    /// Persisted speed (`AppStorageKeys.autoPlayRate`), owned by the caller — same
    /// reasoning as `MoonSizeScrubberNotch.scrub`.
    @Binding var rate: AutoPlayRate
    /// Whether the notch is shown (animated; see `ScrubberNotchContainer`).
    var isPresented: Bool = true
    
    var body: some View {
        ScrubberNotchContainer(side: .trailing, isPresented: isPresented) {
            VerticalGlassSegmentedControl(
                options: AutoPlayRate.allCases,
                selection: $rate,
                title: \.shortLabel,
                accessibilityLabel: "Auto play speed",
                accessibilityValue: \.label
            )
        }
    }
}
