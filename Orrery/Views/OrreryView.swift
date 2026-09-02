//
//  OrreryView.swift
//  Orrery
//
//  Sun + 8 planets + orbit rings, drawn with Canvas (spec §5) — preferred over many
//  individual Shape views since this redraws on every date change.
//

import SwiftUI

struct OrreryView: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let theme: ThemeColors
    /// Frame shape offered to the Canvas. Defaults to the reference web canvas's
    /// 440×392 ratio; the drawing itself is fully radially symmetric (see
    /// `OrreryGeometry.halfSize`, which sizes off `min(width, height)`), so a
    /// container squarer than this default leaves no side unused, while non-square
    /// containers leave a flat margin on whichever axis is longer. Callers that need
    /// a fixed aspect ratio (e.g. the polaroid share card) can rely on the default.
    var aspectRatio: CGFloat = 440.0 / 392.0

    /// Sun dot radius at the reference canvas scale (halfSize 220) — not specified by
    /// name in spec §2's per-planet SIZE table, sized visibly larger than any planet.
    private static let sunReferenceRadius = 14.0

    var body: some View {
        Canvas { context, size in
            draw(context: context, size: size)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .accessibilityLabel("Orrery chart for \(snapshot.date.formatted(.dateTime.year().month().day()))")
    }

    private func draw(context: GraphicsContext, size: CGSize) {
        let halfSize = OrreryGeometry.halfSize(for: size)
        let scale = OrreryGeometry.scale(halfSize: halfSize)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        if showOrbits {
            for config in PlanetConfig.all {
                let r = OrreryGeometry.radius(forDistanceAU: config.orbitAU, halfSize: halfSize)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(theme.orbitStroke), lineWidth: 1)
            }
        }

        drawSun(context: context, center: center, scale: scale)

        for config in PlanetConfig.all {
            guard let value = snapshot.planetValue(named: config.name) else { continue }
            drawPlanet(config: config, value: value, context: context, center: center, halfSize: halfSize, scale: scale)
        }
    }

    private func drawSun(context: GraphicsContext, center: CGPoint, scale: Double) {
        let radius = Self.sunReferenceRadius * scale
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(ThemeColors.sunGradient, center: center, startRadius: 0, endRadius: radius)
        )
    }

    private func drawPlanet(
        config: PlanetConfig, value: PlanetValue, context: GraphicsContext,
        center: CGPoint, halfSize: Double, scale: Double
    ) {
        let dotSize = config.referenceSize * scale
        let position = OrreryGeometry.position(
            distanceAU: value.distanceAU, angleDeg: value.angleDeg, center: center, halfSize: halfSize
        )

        if config.name == "saturn" {
            drawSaturnRing(size: dotSize, angleDeg: value.angleDeg, position: position, scale: scale, context: context)
        }

        let dotRect = CGRect(x: position.x - dotSize, y: position.y - dotSize, width: dotSize * 2, height: dotSize * 2)
        context.fill(Path(ellipseIn: dotRect), with: .color(theme.ink))

        guard showLabels else { return }

        let anchor = OrreryGeometry.labelAnchor(
            distanceAU: value.distanceAU, angleDeg: value.angleDeg, dotSize: dotSize, center: center, halfSize: halfSize
        )
        let text = Text(config.displayName)
            .font(.system(size: max(9, 11 * scale), design: .rounded))
            .foregroundStyle(theme.muted)
        context.draw(text, at: anchor, anchor: unitPoint(for: OrreryGeometry.labelAlignment(angleDeg: value.angleDeg)))
    }

    private func drawSaturnRing(size: Double, angleDeg: Double, position: CGPoint, scale: Double, context: GraphicsContext) {
        let ring = OrreryGeometry.saturnRing(size: size, angleDeg: angleDeg)
        let localRect = CGRect(x: -ring.rx, y: -ring.ry, width: ring.rx * 2, height: ring.ry * 2)
        let transform = CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: ring.rotationDeg * .pi / 180)
        let ringPath = Path(ellipseIn: localRect).applying(transform)
        context.stroke(ringPath, with: .color(theme.muted), lineWidth: max(0.75, 0.75 * scale))
    }

    private func unitPoint(for alignment: OrreryGeometry.LabelAlignment) -> UnitPoint {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center: return .center
        }
    }
}
