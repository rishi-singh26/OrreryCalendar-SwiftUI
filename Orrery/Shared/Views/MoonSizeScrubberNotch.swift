//
//  MoonSizeScrubberNotch.swift
//  Orrery
//
//  The trailing-edge Moon-size scrubber docked in a wedged notch, shared by
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

    private var scrubBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(scrub) },
            set: { scrub = Double($0) }
        )
    }

    private var notchShape: WedgedNotchShape {
        WedgedNotchShape(
            edge: .trailing,
            topCornerRadius: 60,
            wedgeInset: 12,
            outerCornerRadius: 20,
            topCurveFactor: 0.73,
            topCurveDepth: 45
        )
    }

    var body: some View {
        notchShape
            .fill(.background)
            .frame(width: 35, height: 220)
            .overlay {
                // Padded and clipped to the notch's straight-walled middle so the
                // ruler never travels into its flared top/bottom corners.
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
                .frame(height: 160)
                .padding(.horizontal, 10)
            }
            .clipShape(notchShape)
    }
}
