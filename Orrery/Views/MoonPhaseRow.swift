//
//  MoonPhaseRow.swift
//  Orrery
//
//  Northern/Southern hemisphere Moon discs (spec §5). Southern is the same
//  `MoonPhaseShape` mirrored horizontally — no separate calculation needed.
//

import SwiftUI

struct MoonPhaseRow: View {
    let moonPhaseDeg: Double
    let theme: ThemeColors
    /// Continuous scale applied to the discs' base size — lets a caller (e.g. a
    /// scrubber) drive the size smoothly. `1.0`, the default, is the normal size
    /// every call site got back when "Small Moon" was a separate on/off setting.
    var sizeMultiplier: CGFloat = 1.0
    
    var horizontal: Bool = true

    /// Base (unscaled) disc diameter, matching the old "Small Moon" off size.
    private static let baseSize: CGFloat = 68
    /// Once the rendered disc drops below this diameter, labels switch to the
    /// compact "N"/"S" form (with the percentage folded onto the same line) —
    /// what used to be the "Small Moon" setting's fixed look, now triggered by
    /// size instead of a separate toggle.
    private static let compactSizeThreshold: CGFloat = 45

    private var fraction: Double { moonPhaseDeg / 360 }
    private var size: CGFloat { Self.baseSize * sizeMultiplier }
    private var isCompact: Bool { size < Self.compactSizeThreshold }

    private var illuminatedPercent: Int {
        Int(((1 - cos(fraction * 2 * .pi)) / 2 * 100).rounded())
    }
    
    private var layoutSpacing: CGFloat {
        (isCompact ? 100 : 50) * sizeMultiplier
    }
    
    private var layout: AnyLayout {
        horizontal ? AnyLayout(HStackLayout(spacing: layoutSpacing)) : AnyLayout(VStackLayout(spacing: layoutSpacing))
    }

    var body: some View {
        layout {
            disc(mirrored: false, label: isCompact ? "N" : "NORTHERN HEMISPHERE")
            disc(mirrored: true, label: isCompact ? "S" : "SOUTHERN HEMISPHERE")
        }
        .animation(.easeOut(duration: 0.15), value: sizeMultiplier)
    }

    private func disc(mirrored: Bool, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(ThemeColors.moonShadow)
                MoonPhaseShape(fraction: fraction)
                    .fill(ThemeColors.moonLit)
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            // Percentage is always shown; compact sizes fold it onto the same
            // line as the abbreviated label instead of stacking it below.
            if isCompact {
                HStack(spacing: 4) {
                    Text(label)
                    Text("\(illuminatedPercent)%")
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(theme.muted)
                .monospaced()
            } else {
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(theme.muted)
                    .monospaced()

                Text("\(illuminatedPercent)%")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.muted)
                    .monospaced()
            }
        }
    }
}