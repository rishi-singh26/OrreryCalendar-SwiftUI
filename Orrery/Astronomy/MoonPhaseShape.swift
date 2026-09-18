//
//  MoonPhaseShape.swift
//  Orrery
//
//  Renders the Moon's illuminated region for a given phase (spec §2). Ported from the
//  proven-correct web SVG construction via direct point sampling instead of arc
//  sweep-flags — same geometry, without needing to reason about `Path`/`CGPath` sweep
//  semantics:
//
//    theta = fraction * 2π
//    xRadius = |cos(theta)| * r                 // terminator ellipse half-width
//    outerSign = fraction < 0.5 ? +1 : -1        // which side the outer half-circle bulges to
//    innerSign = (fraction < 0.25 || fraction > 0.75) ? outerSign : -outerSign
//
//  The boundary is the outer half-circle (radius r, `outerSign` side, top→bottom) plus
//  the inner terminator ellipse arc (horizontal radius xRadius, `innerSign` side,
//  bottom→top), sampled as polylines and closed into one polygon.
//
//  Checkpoints (verified by hand before, and by `MoonPhaseShapeTests` after):
//    fraction 0.00 (new)     → xRadius == r, innerSign == outerSign → boundaries coincide,
//                              zero area.
//    fraction 0.25 (1st qtr) → xRadius == 0 → inner boundary is the vertical center line,
//                              outer is the right half-circle → exactly right half lit.
//    fraction 0.50 (full)    → xRadius == r, innerSign == -outerSign → the two half-circles
//                              are on opposite sides → union is the whole disc.
//    fraction 0.75 (last qtr)→ mirror of 0.25 → exactly left half lit.
//

import SwiftUI

/// `fraction`: 0 = new moon, 0.25 = first quarter (waxing), 0.5 = full, 0.75 = last
/// quarter (waning), 1 = new again. Equal to `moonPhaseDeg / 360`.
struct MoonPhaseShape: Shape {
    var fraction: Double
    var sampleCount: Int = 48

    nonisolated func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = Self.vertices(fraction: fraction, radius: r, sampleCount: sampleCount)
        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: CGPoint(x: center.x + first.x, y: center.y + first.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: center.x + point.x, y: center.y + point.y))
        }
        path.closeSubpath()
        return path
    }

    /// The boundary polygon in shape-local coordinates, centered at the origin
    /// (positive y downward, matching SwiftUI/Core Graphics).
    nonisolated static func vertices(fraction: Double, radius r: Double, sampleCount: Int) -> [CGPoint] {
        guard r > 0, sampleCount > 0 else { return [] }
        let wrapped = fraction.truncatingRemainder(dividingBy: 1)
        let f = wrapped < 0 ? wrapped + 1 : wrapped
        let theta = f * 2 * .pi
        let xRadius = abs(cos(theta)) * r

        let outerSign: Double = f < 0.5 ? 1 : -1
        let innerSign: Double = (f < 0.25 || f > 0.75) ? outerSign : -outerSign

        var points: [CGPoint] = []
        points.reserveCapacity((sampleCount + 1) * 2)

        // Outer boundary: half-circle, parametrized by angle phi in [-π/2, π/2]
        // so phi = -π/2 is the top pole (y = -r) and phi = π/2 is the bottom pole (y = r).
        for i in 0...sampleCount {
            let t = Double(i) / Double(sampleCount)
            let phi = -Double.pi / 2 + t * Double.pi
            let y = r * sin(phi)
            let x = outerSign * r * cos(phi)
            points.append(CGPoint(x: x, y: y))
        }

        // Inner boundary (terminator): half-ellipse, same angle parametrization,
        // traversed bottom back to top to close the polygon.
        for i in 0...sampleCount {
            let t = Double(i) / Double(sampleCount)
            let phi = Double.pi / 2 - t * Double.pi
            let y = r * sin(phi)
            let x = innerSign * xRadius * cos(phi)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}
