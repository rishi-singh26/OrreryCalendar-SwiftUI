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
    let orbitAU: Double // nominal semi-major axis, for the static orbit ring

    static let all: [PlanetConfig] = [
        PlanetConfig(name: "mercury", displayName: "Mercury", referenceSize: 3, orbitAU: 0.387),
        PlanetConfig(name: "venus", displayName: "Venus", referenceSize: 5, orbitAU: 0.723),
        PlanetConfig(name: "earth", displayName: "Earth", referenceSize: 5.2, orbitAU: 1.000),
        PlanetConfig(name: "mars", displayName: "Mars", referenceSize: 3.6, orbitAU: 1.524),
        PlanetConfig(name: "jupiter", displayName: "Jupiter", referenceSize: 9, orbitAU: 5.203),
        PlanetConfig(name: "saturn", displayName: "Saturn", referenceSize: 8.5, orbitAU: 9.537),
        PlanetConfig(name: "uranus", displayName: "Uranus", referenceSize: 6, orbitAU: 19.191),
        PlanetConfig(name: "neptune", displayName: "Neptune", referenceSize: 6, orbitAU: 30.07),
    ]

    static func config(named name: String) -> PlanetConfig? {
        all.first { $0.name == name }
    }
}

enum OrreryGeometry {
    static let referenceHalfSize = 220.0
    static let rMinFraction = 34.0 / referenceHalfSize
    static let rMaxFraction = 186.0 / referenceHalfSize
    static let minAU = 0.0
    static let maxAU = 30.5

    static func halfSize(for viewSize: CGSize) -> Double {
        min(viewSize.width, viewSize.height) / 2
    }

    /// Scale factor for reference-canvas pixel constants (dot sizes, label offsets,
    /// stroke widths) at the current `halfSize`.
    static func scale(halfSize: Double) -> Double {
        halfSize / referenceHalfSize
    }

    /// Screen-space radius for a heliocentric distance, scaled to `halfSize`. `sqrt`
    /// compresses the outer planets so the whole system fits the chart.
    static func radius(forDistanceAU au: Double, halfSize: Double) -> Double {
        let rMin = halfSize * rMinFraction
        let rMax = halfSize * rMaxFraction
        let t = min(max((au - minAU) / (maxAU - minAU), 0), 1)
        return rMin + (rMax - rMin) * t.squareRoot()
    }

    /// Screen position for a body at `distanceAU`/`angleDeg` (ecliptic longitude),
    /// centered on `center`.
    static func position(distanceAU: Double, angleDeg: Double, center: CGPoint, halfSize: Double) -> CGPoint {
        let r = radius(forDistanceAU: distanceAU, halfSize: halfSize)
        let rad = angleDeg * .pi / 180
        return CGPoint(x: center.x + r * cos(rad), y: center.y + r * sin(rad))
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
    /// `dotSize` is the already-scaled on-screen dot radius.
    static func labelAnchor(
        distanceAU: Double, angleDeg: Double, dotSize: Double, center: CGPoint, halfSize: Double
    ) -> CGPoint {
        let offset = dotSize + 13 * scale(halfSize: halfSize)
        let r = radius(forDistanceAU: distanceAU, halfSize: halfSize) + offset
        let rad = angleDeg * .pi / 180
        return CGPoint(x: center.x + r * cos(rad), y: center.y + r * sin(rad))
    }

    /// Saturn's ring: a thin stroked ellipse layered on the dot, the one intentional
    /// "boldness" flourish besides the Sun/brass accent. `angleDeg` gives it a subtle
    /// day-to-day tilt rather than a fixed orientation.
    static func saturnRing(size: Double, angleDeg: Double) -> (rx: Double, ry: Double, rotationDeg: Double) {
        let rotation = angleDeg.truncatingRemainder(dividingBy: 60) - 30 // subtle -30...30° wobble
        return (rx: size * 1.9, ry: size * 0.6, rotationDeg: rotation)
    }
}
