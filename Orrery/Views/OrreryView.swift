//
//  OrreryView.swift
//  Orrery
//
//  Sun + 8 planets + orbit rings, drawn with Canvas (spec §5) — preferred over many
//  individual Shape views since this redraws on every date change.
//
//  `snapshot` is optional: while it's nil (the data controller hasn't finished its
//  initial compute/load yet) every planet sits in a "loading" pose — lined up directly
//  left of the Sun, one per orbit, via `OrreryGeometry.loadingAngleDeg` — rather than
//  the chart simply not being shown. The first time `snapshot` goes from nil to
//  non-nil, each planet eases from that pose into its real position, always sweeping
//  clockwise (see `OrreryEntranceAnimation` for the timing/easing, `animationSweepDirection`
//  below for the direction). Later snapshot changes snap straight to the new position,
//  unanimated, by default — e.g. the scrub timeline, which already gives continuous
//  visual feedback while dragging — *unless* the caller bumps
//  `dateChangeAnimationTrigger` (see its doc comment), in which case that one
//  transition eases the same way the launch entrance does, just starting from wherever
//  the chart currently sits instead of the loading pose, and sweeping counter-clockwise
//  for a forward-in-time jump or clockwise for a backward one — matching the real
//  orbital direction (see `OrreryGeometry.position`'s doc comment) rather than an
//  arbitrary shortest-path guess. All three cases share one mechanism: see
//  `animationStartDate`/`animationFromSnapshot`/`animationSweepDirection` below.
//

import SwiftUI

struct OrreryView: View {
    let snapshot: DaySnapshot?
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

    /// Bump (e.g. `+= 1`) whenever the caller wants the *next* `snapshot` change to
    /// ease into place — staggered by orbit, same curve as the launch entrance — in
    /// place of the default instant snap. `ContentViewModel.animatedDateBinding`
    /// bumps this on every real date-picker selection; leave it untouched (its
    /// default) for callers that should keep snapping, e.g. the scrub timeline
    /// (continuous drag already gives live feedback) or `PolaroidShareView` (renders
    /// one snapshot off-screen and never transitions). Compared for inequality
    /// against the last-seen value rather than read as a one-shot signal, matching
    /// how `snapshot` itself is diffed.
    var dateChangeAnimationTrigger: Int = 0

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

    /// The instant the current animated transition started, or `nil` when every
    /// planet is just sitting at its resting position (or once the slowest orbit has
    /// finished and it's reset — see the `.task(id:)` below). Set by either branch in
    /// the `.onChange(of: snapshot)` below: the one-time loading → ready entrance, or
    /// a later date-picker-driven jump.
    @State private var animationStartDate: Date?

    /// The angles to ease *from* during the current transition. `nil` means "ease
    /// from the loading pose" (`OrreryGeometry.loadingAngleDeg`, every planet) — the
    /// launch entrance's starting condition, since there is no prior real snapshot
    /// yet. Set to the just-superseded snapshot for a date-picker-driven jump, so
    /// that transition eases from wherever the chart currently sits instead.
    @State private var animationFromSnapshot: DaySnapshot?

    /// The last `dateChangeAnimationTrigger` value already acted on, so the
    /// `.onChange(of: snapshot)` below can tell a fresh bump (an explicit jump, to
    /// animate) apart from an unrelated `snapshot` change arriving while that bump
    /// goes unconsumed (there is none in practice: `dateChangeAnimationTrigger`
    /// bumps only alongside an actual `selectedDate` change, so a bump and the
    /// resulting `snapshot` change always land in the same update — but tracking
    /// "seen" rather than "did it change since last frame" keeps that guarantee
    /// explicit rather than assumed).
    @State private var seenDateChangeAnimationTrigger = 0

    /// Which way the current transition's angles sweep — `.clockwise` for the launch
    /// entrance (always, regardless of arc length), or forward-in-time =
    /// `.counterClockwise` / backward-in-time = `.clockwise` for an explicit date jump
    /// (matching real orbital motion: every planet's true angle only increases as time
    /// moves forward). Always set alongside `animationStartDate` in `.onChange(of:
    /// snapshot)` below, so it's never stale when `displayAngleDeg` reads it.
    @State private var animationSweepDirection: OrreryGeometry.SweepDirection = .clockwise

    var body: some View {
        Group {
            if let animationStartDate {
                TimelineView(.animation) { context in
                    Canvas { gContext, size in
                        draw(context: gContext, size: size, elapsed: context.date.timeIntervalSince(animationStartDate))
                    }
                }
            } else {
                Canvas { context, size in
                    draw(context: context, size: size, elapsed: nil)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: snapshot) { oldSnapshot, newSnapshot in
            guard let newSnapshot else { return }
            guard let oldSnapshot else {
                // Loading → ready: ease from the loading pose, always sweeping clockwise.
                animationFromSnapshot = nil
                animationSweepDirection = .clockwise
                animationStartDate = Date()
                return
            }
            guard dateChangeAnimationTrigger != seenDateChangeAnimationTrigger else { return }
            // An explicit jump (e.g. a date picker) — ease from wherever the chart
            // currently sits into the new positions.
            seenDateChangeAnimationTrigger = dateChangeAnimationTrigger
            animationFromSnapshot = oldSnapshot
            // Forward in time sweeps counter-clockwise (the real orbital direction);
            // backward in time sweeps clockwise.
            animationSweepDirection = newSnapshot.date >= oldSnapshot.date ? .counterClockwise : .clockwise
            animationStartDate = Date()
        }
        // Stops the `TimelineView` once the slowest (outermost) orbit has settled,
        // rather than leaving it ticking every frame for the rest of the session.
        .task(id: animationStartDate) {
            guard animationStartDate != nil else { return }
            try? await Task.sleep(for: .seconds(OrreryEntranceAnimation.maxDuration))
            guard !Task.isCancelled else { return }
            animationStartDate = nil
        }
    }

    private var accessibilityLabel: String {
        guard let snapshot else { return "Orrery chart, calculating planetary positions" }
        return "Orrery chart for \(snapshot.date.formatted(.dateTime.year().month().day()))"
    }

    private func draw(context: GraphicsContext, size: CGSize, elapsed: TimeInterval?) {
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
            guard let angleDeg = displayAngleDeg(for: config, orbitIndex: index, orbitCount: orbitCount, elapsed: elapsed) else { continue }
            drawPlanet(
                config: config, angleDeg: angleDeg, orbitIndex: index, orbitCount: orbitCount,
                context: context, center: center, halfSize: halfSize, scale: scale
            )
        }
    }

    /// The angle to draw `config` at this frame: `loadingAngleDeg` while there's no
    /// snapshot yet, the real angle once settled, or an eased in-between angle while
    /// this planet's own transition animation is still running — eased from
    /// `animationFromSnapshot`'s angle for this body, or `loadingAngleDeg` if that's
    /// nil (the launch entrance) or doesn't have this body (defensive; in practice
    /// every snapshot carries every configured planet). Returns `nil` only when a
    /// snapshot exists but is missing data for this specific body (mirrors the
    /// original behavior of simply skipping that planet).
    private func displayAngleDeg(for config: PlanetConfig, orbitIndex: Int, orbitCount: Int, elapsed: TimeInterval?) -> Double? {
        guard let snapshot else { return OrreryGeometry.loadingAngleDeg }
        guard let value = snapshot.planetValue(named: config.name) else { return nil }
        guard let elapsed else { return value.angleDeg }

        let progress = OrreryEntranceAnimation.progress(elapsed: elapsed, orbitIndex: orbitIndex, orbitCount: orbitCount)
        guard progress < 1 else { return value.angleDeg }
        let fromAngleDeg = animationFromSnapshot?.planetValue(named: config.name)?.angleDeg ?? OrreryGeometry.loadingAngleDeg
        return OrreryGeometry.interpolatedAngleDeg(from: fromAngleDeg, to: value.angleDeg, progress: progress, direction: animationSweepDirection)
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
        config: PlanetConfig, angleDeg: Double, orbitIndex: Int, orbitCount: Int, context: GraphicsContext,
        center: CGPoint, halfSize: Double, scale: Double
    ) {
        let dotSize = config.referenceSize * scale
        let position = OrreryGeometry.position(
            orbitIndex: orbitIndex, count: orbitCount, angleDeg: angleDeg, center: center, halfSize: halfSize
        )

        let isSaturn = config.name == "saturn"
        if isSaturn {
            drawSaturnRing(size: dotSize, angleDeg: angleDeg, position: position, scale: scale, context: context)
        }

        let dotRect = CGRect(x: position.x - dotSize, y: position.y - dotSize, width: dotSize * 2, height: dotSize * 2)
        context.fill(Path(ellipseIn: dotRect), with: .color(isSaturn ? theme.orrery.saturnBody : theme.orrery.planet))

        guard showLabels else { return }

        let anchor = OrreryGeometry.labelAnchor(
            orbitIndex: orbitIndex, count: orbitCount, angleDeg: angleDeg, dotSize: dotSize, center: center, halfSize: halfSize
        )
        let text = Text(config.displayName)
            .font(.system(size: max(9, 11 * scale), design: .rounded))
            .foregroundStyle(theme.muted)
        context.draw(text, at: anchor, anchor: unitPoint(for: OrreryGeometry.labelAlignment(angleDeg: angleDeg)))
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
