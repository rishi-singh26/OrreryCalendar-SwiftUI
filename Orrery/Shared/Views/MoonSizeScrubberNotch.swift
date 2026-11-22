//
//  MoonSizeScrubberNotch.swift
//  Orrery
//
//  The leading-edge Moon-size scrubber docked in a wedged notch, shared by
//  `SmallScreenView` and `LargeScreenView`. Placement (padding/frame/offset) is
//  left to each caller since it differs per layout.
//

import SwiftUI

struct MoonSizeScrubberNotch: View {
    /// Persisted, normalized (`0...1`) scrubber position (`AppStorageKeys.moonSizeScrub`).
    /// Owned by the caller, which needs it for the Moon-size multiplier; `@AppStorage` only
    /// integrates with SwiftUI's update machinery when declared on a `View`, and it only
    /// bridges `Double` natively — so this view hands `VerticalScrubber` a `CGFloat` adapter.
    @Binding var scrub: Double
    let theme: ThemeColors
    /// Whether the notch is shown (animated; see `ScrubberNotchContainer`).
    var isPresented: Bool = true
    
    private var scrubBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(scrub) },
            set: { scrub = Double($0) }
        )
    }
    
    var body: some View {
        ScrubberNotchContainer(side: .leading, isPresented: isPresented) {
            VerticalScrubber(
                value: scrubBinding,
                tickCount: 30,
                visibleTickCount: 12,
                tickThickness: 2,
                tickLength: 16,
                dimColor: theme.ink.opacity(0.5),
                accentColor: .accentColor,
                accessibilityLabel: "Moon size"
            )
            .padding(.horizontal, 10)
        }
    }
}
