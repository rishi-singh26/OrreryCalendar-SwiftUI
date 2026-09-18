//
//  RoundedPolygon.swift
//  Orrery
//
//  Created by Rishi Singh on 14/09/26.
//

import SwiftUI

/// A generic animatable vector of Doubles, used to animate arrays of values (like point lists)
struct AnimatableVector: VectorArithmetic {
    var values: [Double]

    static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        AnimatableVector(values: zip(lhs.values, rhs.values).map(+))
    }

    static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        AnimatableVector(values: zip(lhs.values, rhs.values).map(-))
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    static var zero: AnimatableVector { AnimatableVector(values: []) }
}

struct RoundedPolygon: Shape {
    var relativePoints: [CGPoint]
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let points = relativePoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width,
                    y: rect.minY + $0.y * rect.height)
        }
        guard points.count > 2 else { return Path() }

        let cgPath = CGMutablePath()
        cgPath.move(to: points[points.count - 1])

        for i in 0..<points.count {
            let next = points[(i + 1) % points.count]
            cgPath.addArc(tangent1End: points[i], tangent2End: next, radius: cornerRadius)
        }
        cgPath.closeSubpath()

        return Path(cgPath)
    }
}

struct StepShape: Shape {
    static let defaultPoints: [CGPoint] = [
        CGPoint(x: 0.48, y: 0.16),
        CGPoint(x: 0.90, y: 0.16),
        CGPoint(x: 0.90, y: 0.80),
        CGPoint(x: 0.09, y: 0.80),
        CGPoint(x: 0.09, y: 0.45),
        CGPoint(x: 0.48, y: 0.45)
    ]
    
    static let defaultCornerRadius: CGFloat = 24

    var points: [CGPoint]
    var cornerRadius: CGFloat

    init(points: [CGPoint]? = nil, cornerRadius: CGFloat? = nil) {
        self.points = points ?? StepShape.defaultPoints
        self.cornerRadius = cornerRadius ?? StepShape.defaultCornerRadius
    }

    var animatableData: AnimatableVector {
        get {
            AnimatableVector(values: points.flatMap { [Double($0.x), Double($0.y)] })
        }
        set {
            var newPoints: [CGPoint] = []
            newPoints.reserveCapacity(newValue.values.count / 2)
            var i = 0
            while i < newValue.values.count {
                newPoints.append(CGPoint(x: newValue.values[i], y: newValue.values[i + 1]))
                i += 2
            }
            points = newPoints
        }
    }

    func path(in rect: CGRect) -> Path {
        RoundedPolygon(relativePoints: points, cornerRadius: cornerRadius).path(in: rect)
    }
}

fileprivate struct ScrubberShape: View {
    @State private var points: [CGPoint] = [
        CGPoint(x: 0.5, y: 0.75),  // top-left of upper block
        CGPoint(x: 0.99, y: 0.75),  // top-right
        CGPoint(x: 0.99, y: 0.98),  // bottom-right
        CGPoint(x: 0.01, y: 0.98),  // bottom-left
        CGPoint(x: 0.01, y: 0.85),  // up to lower block's left edge
        CGPoint(x: 0.5, y: 0.85)   // inner corner, back to start
    ]
    
    func openToShape() {
        withAnimation(.easeInOut(duration: 0.2)) {
            points = [
                CGPoint(x: 0.5, y: 0.1),  // top-left of upper block
                CGPoint(x: 0.99, y: 0.1),  // top-right
                CGPoint(x: 0.99, y: 0.98),  // bottom-right
                CGPoint(x: 0.01, y: 0.98),  // bottom-left
                CGPoint(x: 0.01, y: 0.85),  // up to lower block's left edge
                CGPoint(x: 0.5, y: 0.85)   // inner corner, back to start
            ]
        }
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack {
                StepShape(points: points, cornerRadius: 20)
                    .glassOrSurface(glass: .tinted(ThemeColors.controlsBarTint), in: StepShape(points: points, cornerRadius: 20))
                // .stroke(lineWidth: 2)   // Shape-returning overload, no color yet
                //.fill(Color.black)      // color applied last, keeps Shape identity intact
                    .border(.red)
                
                Button("Update", action: openToShape)
            }
        }
    }
}

#Preview {
    ScrubberShape()
}
