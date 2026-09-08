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
    let showSunHalo: Bool
    let theme: ThemeColors
    /// Frame shape offered to the Canvas. Defaults to the reference web canvas's
    /// 440×392 ratio; the drawing itself is fully radially symmetric (see
    /// `OrreryGeometry.halfSize`, which sizes off `min(width, height)`), so a
    /// container squarer than this default leaves no side unused, while non-square
    /// containers leave a flat margin on whichever axis is longer. Callers that need
    /// a fixed aspect ratio (e.g. the polaroid share card) can rely on the default.
    var aspectRatio: CGFloat = 440.0 / 392.0

    // Sun dot radius at the reference canvas scale (halfSize 220) — not specified by
    // name in spec §2's per-planet SIZE table, sized visibly larger than any planet.
    // If sunReferenceRadius was originally derived as orreryWidth * (X / 340) / 2,
    // keep these consistent with that same reference orreryWidth of 340.
    static let sunCoreReferenceRadius: Double = 15  // 30 / 2, i.e. (30.0 / 340.0) * 340 / 2

    /// The halo's reference-scale radius, pinned to exactly Venus's orbit radius
    /// rather than a hand-picked constant — both are computed from `halfSize` the
    /// same linear way (see `OrreryGeometry.radius`), so `haloRadius == orbitRadius`
    /// holds at every canvas size, not just at the reference scale.
    static let sunHaloReferenceRadius: Double = {
        let orbitCount = PlanetConfig.all.count
        let venusIndex = PlanetConfig.all.firstIndex { $0.name == "venus" } ?? 1
        return OrreryGeometry.radius(forOrbitIndex: venusIndex, count: orbitCount, halfSize: OrreryGeometry.referenceHalfSize)
    }()

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

        let orbitCount = PlanetConfig.all.count

        if showOrbits {
            for index in 0..<orbitCount {
                let r = OrreryGeometry.radius(forOrbitIndex: index, count: orbitCount, halfSize: halfSize)
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(theme.orrery.orbitStroke.opacity(theme.orrery.orbitOpacity)), lineWidth: 1)
            }
        }

        drawSun(context: context, center: center, scale: scale)

        for (index, config) in PlanetConfig.all.enumerated() {
            guard let value = snapshot.planetValue(named: config.name) else { continue }
            drawPlanet(
                config: config, value: value, orbitIndex: index, orbitCount: orbitCount,
                context: context, center: center, halfSize: halfSize, scale: scale
            )
        }
    }

    private func drawSun(context: GraphicsContext, center: CGPoint, scale: Double) {
        let coreRadius = Self.sunCoreReferenceRadius * scale
        let haloRadius = Self.sunHaloReferenceRadius * scale

        // Halo
        if showSunHalo {
            let haloRect = CGRect(
                x: center.x - haloRadius,
                y: center.y - haloRadius,
                width: haloRadius * 2,
                height: haloRadius * 2
            )
            context.fill(
                Path(ellipseIn: haloRect),
                with: .color(theme.orrery.sunHalo.opacity(theme.orrery.sunHaloOpacity))
            )
        }

        // Core
        let coreRect = CGRect(
            x: center.x - coreRadius,
            y: center.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )

        // Off-center focal point, matching UnitPoint(x: 0.38, y: 0.34) from the original RadialGradient view
        let gradientCenter = CGPoint(
            x: coreRect.minX + coreRect.width * 0.38,
            y: coreRect.minY + coreRect.height * 0.34
        )

        context.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                ThemeColors.sunCoreGradient,
                center: gradientCenter,
                startRadius: 0,
                endRadius: coreRadius * 1.44 // = coreDiameter * 0.72
            )
        )
    }

    private func drawPlanet(
        config: PlanetConfig, value: PlanetValue, orbitIndex: Int, orbitCount: Int, context: GraphicsContext,
        center: CGPoint, halfSize: Double, scale: Double
    ) {
        let dotSize = config.referenceSize * scale
        let position = OrreryGeometry.position(
            orbitIndex: orbitIndex, count: orbitCount, angleDeg: value.angleDeg, center: center, halfSize: halfSize
        )

        let isSaturn = config.name == "saturn"
        if isSaturn {
            drawSaturnRing(size: dotSize, angleDeg: value.angleDeg, position: position, scale: scale, context: context)
        }

        let dotRect = CGRect(x: position.x - dotSize, y: position.y - dotSize, width: dotSize * 2, height: dotSize * 2)
        context.fill(Path(ellipseIn: dotRect), with: .color(isSaturn ? theme.orrery.saturnBody : theme.orrery.planet))

        guard showLabels else { return }

        let anchor = OrreryGeometry.labelAnchor(
            orbitIndex: orbitIndex, count: orbitCount, angleDeg: value.angleDeg, dotSize: dotSize, center: center, halfSize: halfSize
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
        context.stroke(ringPath, with: .color(theme.orrery.planet), lineWidth: max(0.75, 0.75 * scale))
    }

    private func unitPoint(for alignment: OrreryGeometry.LabelAlignment) -> UnitPoint {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center: return .center
        }
    }
}
