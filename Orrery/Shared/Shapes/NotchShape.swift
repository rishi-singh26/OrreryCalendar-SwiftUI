//
//  NotchShape.swift
//  Orrery
//
//  Created by Rishi Singh on 08/09/26.
//

import SwiftUI

struct NotchShape: Shape {
    /// The screen edge the notch attaches to.
    var edge: NotchEdge = .top
    // Horizontal inset of the two concave corner flares.
    var topCornerRadius: CGFloat
    // Corner radius where the flat outer (protruding) edge meets the side walls.
    var bottomCornerRadius: CGFloat
    // Controls how fat the top flare's cubic curve is. 0.5523 ≈ a circular arc;
    // higher values push toward a smoother, more pronounced "liquid glass" sweep.
    var topCurveFactor: CGFloat = 0.8
    // How far down the wall the top flare reaches (its Y end point). When nil it
    // matches `topCornerRadius`, giving a symmetric corner.
    var topCurveDepth: CGFloat? = nil

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // Build the notch in a canonical "attached to top" orientation — flat
        // wide edge along the local x-axis, body protruding down +y — then map
        // it onto the requested edge with an affine transform.
        //
        // `length` runs along the attached edge; `depth` is how far it protrudes.
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
            // Identity (only offset to the rect's origin).
            transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
        case .bottom:
            // Flip vertically: wide edge drops to the bottom, body points up.
            transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: rect.minX, ty: rect.maxY)
        case .leading:
            // Swap axes: wide edge runs down the left, body points right.
            transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: rect.minX, ty: rect.minY)
        case .trailing:
            // Swap axes and flip: wide edge runs down the right, body points left.
            transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: rect.maxX, ty: rect.minY)
        }

        return canonical.applying(transform)
    }

    /// Builds the notch attached to the top edge, drawn within
    /// `CGRect(x: 0, y: 0, width: length, height: depth)`.
    private func canonicalPath(length: CGFloat, depth: CGFloat) -> Path {
        let minX: CGFloat = 0, maxX = length
        let minY: CGFloat = 0, maxY = depth

        // Horizontal inset of the flares. The top flare + outer corner on the
        // same side must fit within half the length, so scale both down if needed.
        let topR = max(0, topCornerRadius)
        let bottomR = max(0, min(bottomCornerRadius, depth / 2))
        let scale = min(1, (length / 2) / max(topR + bottomR, 1))
        let tR = topR * scale
        let bR = bottomR * scale

        // How far the top flares reach along the depth, clamped so they never
        // collide with the rounded outer corners.
        let tDepth = max(0, min(topCurveDepth ?? topR, depth - bR))

        // Pull distances for the top flare's cubic control points: along the edge
        // at the top, across the depth where it lands on the wall.
        let kH = tR * topCurveFactor
        let kV = tDepth * topCurveFactor

        var path = Path()

        // Start at the top-left outer corner of the wide top edge.
        path.move(to: CGPoint(x: minX, y: minY))

        // Top-left concave flare: the top edge is wider than the wall below it,
        // so the corner curves *inward*. The cubic leaves the top edge
        // horizontally and settles onto the wall vertically for a smooth sweep.
        path.addCurve(
            to: CGPoint(x: minX + tR, y: minY + tDepth),
            control1: CGPoint(x: minX + kH, y: minY),
            control2: CGPoint(x: minX + tR, y: minY + tDepth - kV)
        )

        // Left wall, down to the rounded outer corner.
        path.addLine(to: CGPoint(x: minX + tR, y: maxY - bR))

        // Bottom-left rounded corner (convex): wall meets the flat outer edge.
        path.addQuadCurve(
            to: CGPoint(x: minX + tR + bR, y: maxY),
            control: CGPoint(x: minX + tR, y: maxY)
        )

        // Flat outer (protruding) edge.
        path.addLine(to: CGPoint(x: maxX - tR - bR, y: maxY))

        // Bottom-right rounded corner (convex).
        path.addQuadCurve(
            to: CGPoint(x: maxX - tR, y: maxY - bR),
            control: CGPoint(x: maxX - tR, y: maxY)
        )

        // Right wall, back up to the flare.
        path.addLine(to: CGPoint(x: maxX - tR, y: minY + tDepth))

        // Top-right concave flare (mirror of the top-left cubic): leaves the
        // wall vertically and settles onto the top edge horizontally.
        path.addCurve(
            to: CGPoint(x: maxX, y: minY),
            control1: CGPoint(x: maxX - tR, y: minY + tDepth - kV),
            control2: CGPoint(x: maxX - kH, y: minY)
        )

        // Wide flat top edge (closing back to the start point).
        path.closeSubpath()
        return path
    }
}

fileprivate struct NotchDemo: View {
    @State private var curveFactor: CGFloat = 0.8
    @State private var curveDepth: CGFloat = 34
    @State private var outerRadius: CGFloat = 24

    // Length of the notch along the right edge, and how far it protrudes inward.
    private let notchLength: CGFloat = 300
    private let notchDepth: CGFloat = 64

    var body: some View {
        VStack(spacing: 40) {
            // A mock "screen" with a wallpaper, and a white notch glued to the
            // right edge — mirroring the reference image.
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.87, green: 0.72, blue: 0.53),
                             Color(red: 0.78, green: 0.58, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                NotchShape(
                    edge: .trailing,
                    topCornerRadius: 30,
                    bottomCornerRadius: outerRadius,
                    topCurveFactor: curveFactor,
                    topCurveDepth: curveDepth
                )
                .fill(Color.white)
                .frame(width: notchDepth, height: notchLength)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            .frame(width: 300, height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 44))

            VStack(spacing: 16) {
                VStack {
                    Text("Top curve: \(curveFactor, specifier: "%.2f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $curveFactor, in: 0...1.5)
                }
                VStack {
                    Text("Curve depth: \(curveDepth, specifier: "%.0f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $curveDepth, in: 0...120)
                }
                VStack {
                    Text("Outer corner radius: \(outerRadius, specifier: "%.0f")")
                        .font(.caption.monospacedDigit())
                    Slider(value: $outerRadius, in: 0...32)
                }
            }
            .frame(width: 260)
        }
        .padding()
    }
}

#Preview {
    NotchDemo()
}
