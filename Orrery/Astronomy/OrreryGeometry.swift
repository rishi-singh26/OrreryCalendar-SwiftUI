//
//  OrreryGeometry.swift
//  Orrery
//
//  Planet position → screen coordinate math, ported exactly from the validated web
//  prototype (spec §2). Reference canvas was 440×392, center (220,196), R_MIN=34,
//  R_MAX=186 — everything here is expressed as a fraction of `halfSize` so it scales to
//  any window.
//

import CoreGraphics
import Foundation

/// Static per-planet visual constants at the reference canvas scale (half-size 220pt).
/// `name` matches `PlanetEngineClient.bodyNames` / `CelestialBody.rawValue`.
struct PlanetConfig {
    let name: String
    let displayName: String
    let referenceSize: Double // dot radius in px, at halfSize == 220

    /// Ordered innermost (Mercury) to outermost (Neptune) — this order, not any AU
    /// value, is what determines each planet's orbit ring in `OrreryGeometry`.
    static let all: [PlanetConfig] = [
        PlanetConfig(name: "mercury", displayName: "Mercury", referenceSize: 3),
        PlanetConfig(name: "venus", displayName: "Venus", referenceSize: 5),
        PlanetConfig(name: "earth", displayName: "Earth", referenceSize: 5.2),
        PlanetConfig(name: "mars", displayName: "Mars", referenceSize: 3.6),
        PlanetConfig(name: "jupiter", displayName: "Jupiter", referenceSize: 9),
        PlanetConfig(name: "saturn", displayName: "Saturn", referenceSize: 8.5),
        PlanetConfig(name: "uranus", displayName: "Uranus", referenceSize: 6),
        PlanetConfig(name: "neptune", displayName: "Neptune", referenceSize: 6),
    ]

    static func config(named name: String) -> PlanetConfig? {
        all.first { $0.name == name }
    }
}

enum OrreryGeometry {
    static let referenceHalfSize = 220.0
    static let rMinFraction = 34.0 / referenceHalfSize
    static let rMaxFraction = 186.0 / referenceHalfSize

    /// Ecliptic longitude every planet sits at in `OrreryView`'s loading pose — 180°
    /// puts each one directly left of the Sun (`cos(180°) == -1`, `sin(180°) == 0` in
    /// `position(orbitIndex:count:angleDeg:center:halfSize:)`), i.e. one straight line
    /// running left from the Sun, each planet on its own orbit radius.
    static let loadingAngleDeg: Double = 180

    static func halfSize(for viewSize: CGSize) -> Double {
        min(viewSize.width, viewSize.height) / 2
    }

    /// Scale factor for reference-canvas pixel constants (dot sizes, label offsets,
    /// stroke widths) at the current `halfSize`.
    static func scale(halfSize: Double) -> Double {
        halfSize / referenceHalfSize
    }

    /// Screen-space radius for the `index`-th orbit out of `count` total, evenly spaced
    /// from `rMin` (innermost, index 0) to `rMax` (outermost, index `count - 1`) —
    /// orbits are drawn equidistant rather than scaled to any real distance.
    static func radius(forOrbitIndex index: Int, count: Int, halfSize: Double) -> Double {
        let rMin = halfSize * rMinFraction
        let rMax = halfSize * rMaxFraction
        guard count > 1 else { return rMin }
        let t = Double(index) / Double(count - 1)
        return rMin + (rMax - rMin) * t
    }

    /// Screen position for a body on the `index`-th of `count` orbits, at `angleDeg`
    /// (ecliptic longitude), centered on `center`. `angleDeg` increases counter-clockwise,
    /// the direction planets actually orbit as seen from ecliptic north; the `y` term is
    /// negated to counteract SwiftUI's downward-increasing y-axis, which would otherwise
    /// mirror that into apparent clockwise motion on screen.
    static func position(orbitIndex: Int, count: Int, angleDeg: Double, center: CGPoint, halfSize: Double) -> CGPoint {
        let r = radius(forOrbitIndex: orbitIndex, count: count, halfSize: halfSize)
        let rad = angleDeg * .pi / 180
        return CGPoint(x: center.x + r * cos(rad), y: center.y - r * sin(rad))
    }

    /// Which way an interpolated angle sweeps on screen — see `position`'s doc comment
    /// for why increasing `angleDeg` reads as counter-clockwise once the y-axis negation
    /// is accounted for.
    enum SweepDirection {
        case clockwise
        case counterClockwise
    }

    /// Interpolates from `start` to `end` (both ecliptic-longitude degrees), sweeping in
    /// the given `direction` regardless of which way is the shorter arc — `OrreryView`
    /// picks `.clockwise` for the launch entrance (always) and forward/backward-in-time
    /// jumps for date-picker/"Today" transitions (`.counterClockwise`/`.clockwise`,
    /// matching the real orbital direction; see `position`'s doc comment). `progress` is
    /// `0...1`, already eased by the caller.
    static func interpolatedAngleDeg(from start: Double, to end: Double, progress: Double, direction: SweepDirection) -> Double {
        let forwardDelta = (end - start).truncatingRemainder(dividingBy: 360)
        let normalizedForwardDelta = (forwardDelta + 360).truncatingRemainder(dividingBy: 360) // [0, 360)
        let delta: Double
        switch direction {
        case .counterClockwise:
            delta = normalizedForwardDelta
        case .clockwise:
            // Avoid a spurious full 360° sweep when start == end (mod 360) — with no
            // rotation needed, neither direction should move at all.
            delta = normalizedForwardDelta == 0 ? 0 : normalizedForwardDelta - 360
        }
        return start + delta * progress
    }

    enum LabelAlignment {
        case leading, trailing, center
    }

    /// Which side of the Sun the label falls on, so labels don't run off the chart edge.
    static func labelAlignment(angleDeg: Double) -> LabelAlignment {
        let c = cos(angleDeg * .pi / 180)
        if c > 0.35 { return .leading }
        if c < -0.35 { return .trailing }
        return .center
    }

    /// Label anchor point: along the same radial line as the dot, just past it.
    /// `dotSize` is the already-scaled on-screen dot radius. `y` is negated for the same
    /// reason as in `position(orbitIndex:count:angleDeg:center:halfSize:)`, so the label
    /// lands on the same ray as the dot it belongs to.
    static func labelAnchor(
        orbitIndex: Int, count: Int, angleDeg: Double, dotSize: Double, center: CGPoint, halfSize: Double
    ) -> CGPoint {
        let offset = dotSize + 13 * scale(halfSize: halfSize)
        let r = radius(forOrbitIndex: orbitIndex, count: count, halfSize: halfSize) + offset
        let rad = angleDeg * .pi / 180
        return CGPoint(x: center.x + r * cos(rad), y: center.y - r * sin(rad))
    }

    /// Saturn's ring: a thin stroked ellipse layered on the dot, the one intentional
    /// "boldness" flourish besides the Sun/brass accent. `angleDeg` gives it a subtle
    /// day-to-day tilt rather than a fixed orientation.
    static func saturnRing(size: Double, angleDeg: Double) -> (rx: Double, ry: Double, rotationDeg: Double) {
        let rotation = angleDeg.truncatingRemainder(dividingBy: 60) - 30 // subtle -30...30° wobble
        return (rx: size * 1.9, ry: size * 0.6, rotationDeg: rotation)
    }
}
