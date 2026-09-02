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
    let smallMoon: Bool
    let theme: ThemeColors

    private var fraction: Double { moonPhaseDeg / 360 }

    private var illuminatedPercent: Int {
        Int(((1 - cos(fraction * 2 * .pi)) / 2 * 100).rounded())
    }

    var body: some View {
        HStack(spacing: smallMoon ? 100 : 50) {
            disc(mirrored: false, label: smallMoon ? "N" : "Northern hemisphere")
            disc(mirrored: true, label: smallMoon ? "S" : "Southern hemisphere")
        }
    }

    private func disc(mirrored: Bool, label: String) -> some View {
        let size: CGFloat = smallMoon ? 30 : 68
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(ThemeColors.moonShadow)
                MoonPhaseShape(fraction: fraction)
                    .fill(ThemeColors.moonLit)
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            Text(label)
                .font(.system(size: smallMoon ? 11 : 12, design: .rounded))
                .foregroundStyle(theme.muted)

            if !smallMoon {
                Text("\(illuminatedPercent)%")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.muted)
            }
        }
    }
}
