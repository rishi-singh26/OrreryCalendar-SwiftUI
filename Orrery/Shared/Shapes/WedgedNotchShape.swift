//
//  WedgedNotchShape.swift
//  Orrery
//
//  Created by Rishi Singh on 08/09/26.
//

import SwiftUI

/// A notch whose side walls angle inward like a trapezium (a "wedge"), rather
/// than running straight. The wide edge sits against a screen edge, the body
/// tapers toward a narrower flat outer edge, and the two outer vertices are
/// rounded by a customizable corner radius.
/// 12 23 44 0.73
struct WedgedNotchShape: Shape {
    /// The screen edge the notch attaches to.
    var edge: NotchEdge = .top
    /// Horizontal inset of the two concave corner flares at the wide edge.
    var topCornerRadius: CGFloat
    /// How far each wall angles inward from the wide edge to the outer edge.
    var wedgeInset: CGFloat
    /// Corner radius of the two outer vertices (where the walls meet the outer edge).
    var outerCornerRadius: CGFloat
    // Controls how fat the flare's cubic curve is; higher = smoother sweep.
    var topCurveFactor: CGFloat = 0.8
    // How far the flares reach along the depth. When nil it matches `topCornerRadius`.
    var topCurveDepth: CGFloat? = nil

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(topCornerRadius, AnimatablePair(wedgeInset, outerCornerRadius)) }
        set {
            topCornerRadius = newValue.first
            wedgeInset = newValue.second.first
            outerCornerRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // Same canonical-then-transform approach as `NotchShape`: build attached
        // to the top edge, then map onto the requested edge.
        let length: CGFloat
        let depth: CGFloat
        switch edge {
        case .top, .bottom:
            length = rect.width
            depth = rect.height
        case .leading, .trailing:
            length = rect.height
            depth = rect.width
        }

        let canonical = canonicalPath(length: length, depth: depth)

        let transform: CGAffineTransform
        switch edge {
        case .top:
            transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        case .bottom:
            transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.maxY)
        case .leading:
            transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: rect.minX, ty: rect.minY)
        case .trailing:
            transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: rect.maxX, ty: rect.minY)
        }

        return canonical.applying(transform)
    }

    /// Builds the wedged notch attached to the top edge, within
    /// `CGRect(x: 0, y: 0, width: length, height: depth)`.
    private func canonicalPath(length: CGFloat, depth: CGFloat) -> Path {
        let minX: CGFloat = 0, maxX = length
        let minY: CGFloat = 0, maxY = depth

        let topR = max(0, min(topCornerRadius, length / 2))
        let tDepth = max(0, min(topCurveDepth ?? topR, depth))

        // Wedge inset, clamped so the walls don't cross past the center.
        let maxInset = max(0, length / 2 - topR)
        let inset = min(max(0, wedgeInset), maxInset)

        // Outer-vertex rounding, clamped to the outer edge half-width and wall.
        let outerHalf = max(0, length / 2 - topR - inset)
        let wallLen = hypot(inset, maxY - tDepth)
        let outerR = max(0, min(outerCornerRadius, outerHalf, wallLen))

        // Pull distances for the flare's cubic control points.
        let kH = topR * topCurveFactor
        let kV = tDepth * topCurveFactor

        // Key vertices (before rounding the outer ones).
        let a = CGPoint(x: minX + topR, y: minY + tDepth)          // left wall top
        let b = CGPoint(x: minX + topR + inset, y: maxY)           // left outer vertex
        let c = CGPoint(x: maxX - topR - inset, y: maxY)           // right outer vertex
        let d = CGPoint(x: maxX - topR, y: minY + tDepth)          // right wall top

        // Unit vectors up each slanted wall, used to offset the rounded corners.
        let leftUp = wallLen > 0
            ? CGPoint(x: (a.x - b.x) / wallLen, y: (a.y - b.y) / wallLen)
            : CGPoint(x: 0, y: -1)
        let rightUp = wallLen > 0
            ? CGPoint(x: (d.x - c.x) / wallLen, y: (d.y - c.y) / wallLen)
            : CGPoint(x: 0, y: -1)

        let b1 = CGPoint(x: b.x + outerR * leftUp.x, y: b.y + outerR * leftUp.y)
        let b2 = CGPoint(x: b.x + outerR, y: b.y)
        let c2 = CGPoint(x: c.x - outerR, y: c.y)
        let c1 = CGPoint(x: c.x + outerR * rightUp.x, y: c.y + outerR * rightUp.y)

        var path = Path()

        // Start at the top-left outer corner of the wide edge.
        path.move(to: CGPoint(x: minX, y: minY))

        // Top-left concave flare. It leaves the wide edge horizontally and
        // arrives *tangent to the slanted wall* (control2 aimed back up the
        // wall via `leftUp`), so the flare blends smoothly into the wall with
        // no kink.
        path.addCurve(
            to: a,
            control1: CGPoint(x: minX + kH, y: minY),
            control2: CGPoint(x: a.x + kV * leftUp.x, y: a.y + kV * leftUp.y)
        )

        // Left slanted wall down to the rounded outer vertex.
        path.addLine(to: b1)
        path.addQuadCurve(to: b2, control: b)

        // Flat (narrower) outer edge.
        path.addLine(to: c2)

        // Right rounded outer vertex, then slanted wall back up.
        path.addQuadCurve(to: c1, control: c)
        path.addLine(to: d)

        // Top-right concave flare (mirror): leaves the wall tangentially and
        // settles onto the wide edge horizontally.
        path.addCurve(
            to: CGPoint(x: maxX, y: minY),
            control1: CGPoint(x: d.x + kV * rightUp.x, y: d.y + kV * rightUp.y),
            control2: CGPoint(x: maxX - kH, y: minY)
        )

        path.closeSubpath()
        return path
    }
}

fileprivate struct WedgedNotchDemo: View {
    @State private var edge: NotchEdge = .trailing
    @State private var wedgeInset: CGFloat = 12
    @State private var outerRadius: CGFloat = 20
    @State private var curveDepth: CGFloat = 45
    @State private var innerCurve: CGFloat = 0.73

    // Length of the notch along its edge, and how far it protrudes inward.
    private let notchLength: CGFloat = 340
    private let notchDepth: CGFloat = 50

    // For top/bottom the length runs horizontally; for left/right it runs vertically.
    private var isHorizontal: Bool {
        switch edge {
        case .top, .bottom: return true
        case .leading, .trailing: return false
        }
    }

    private var notchAlignment: Alignment {
        switch edge {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Picker("Edge", selection: $edge) {
                ForEach(NotchEdge.allCases, id: \.self) { edge in
                    Text(edge.title).tag(edge)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            // A mock "screen" with a white wedged notch glued to the chosen edge.
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.87, green: 0.72, blue: 0.53),
                             Color(red: 0.78, green: 0.58, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                WedgedNotchShape(
                    edge: edge,
                    topCornerRadius: 60,
                    wedgeInset: wedgeInset,
                    outerCornerRadius: outerRadius,
                    topCurveFactor: innerCurve,
                    topCurveDepth: curveDepth
                )
                .fill(Color.white)
                .frame(
                    width: isHorizontal ? notchLength : notchDepth,
                    height: isHorizontal ? notchDepth : notchLength
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: notchAlignment)
            }
            .frame(width: 340, height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 44))

            VStack(spacing: 16) {
                VStack {
                    Text("Wedge inset: \(wedgeInset, specifier: "%.0f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $wedgeInset, in: 0...80)
                }
                VStack {
                    Text("Outer corner radius: \(outerRadius, specifier: "%.0f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $outerRadius, in: 0...40)
                }
                VStack {
                    Text("Curve depth: \(curveDepth, specifier: "%.0f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $curveDepth, in: 0...80)
                }
                VStack {
                    Text("Inner curve: \(innerCurve, specifier: "%.2f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $innerCurve, in: 0...1.5)
                }
            }
            .frame(width: 260)
        }
        .padding()
    }
}

#Preview("Wedged") {
    WedgedNotchDemo()
}
