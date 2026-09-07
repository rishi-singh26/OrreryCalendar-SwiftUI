//
//  Semicircle.swift
//  Orrery
//
//  Created by Rishi Singh on 07/09/26.
//

import SwiftUI

struct Semicircle: Shape {
    enum Direction {
        case left, right, full
        case topHalf, bottomHalf
        case topLeading, topTrailing
        case bottomLeading, bottomTrailing
    }

    var direction: Direction

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        switch direction {
        case .full:
            var path = Path()
            path.addArc(center: center, radius: radius,
                        startAngle: .degrees(0), endAngle: .degrees(360),
                        clockwise: false)
            return path

        // Halves — flat chord on one side, arc bulging the other
        case .right:      return halfPath(center: center, radius: radius, startAngle: -90, endAngle: 90)
        case .left:       return halfPath(center: center, radius: radius, startAngle: 90,  endAngle: 270)
        case .topHalf:    return halfPath(center: center, radius: radius, startAngle: -180, endAngle: 0)
        case .bottomHalf: return halfPath(center: center, radius: radius, startAngle: 0,   endAngle: 180)

        // Quarters — pie-slice wedges (two radii + arc), one per corner
        case .topLeading:     return quarterPath(center: center, radius: radius, startAngle: -180, endAngle: -90)
        case .topTrailing:    return quarterPath(center: center, radius: radius, startAngle: -90,  endAngle: 0)
        case .bottomTrailing: return quarterPath(center: center, radius: radius, startAngle: 0,    endAngle: 90)
        case .bottomLeading:  return quarterPath(center: center, radius: radius, startAngle: 90,   endAngle: 180)
        }
    }

    /// Arc + straight chord back to the start point (semicircle)
    private func halfPath(center: CGPoint, radius: CGFloat, startAngle: Double, endAngle: Double) -> Path {
        var path = Path()
        let start = CGPoint(
            x: center.x + radius * cos(Angle(degrees: startAngle).radians),
            y: center.y + radius * sin(Angle(degrees: startAngle).radians)
        )
        path.move(to: start)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(startAngle), endAngle: .degrees(endAngle),
                    clockwise: false)
        path.closeSubpath()
        return path
    }

    /// Two radii + arc, forming a pie-slice quarter circle
    private func quarterPath(center: CGPoint, radius: CGFloat, startAngle: Double, endAngle: Double) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(startAngle), endAngle: .degrees(endAngle),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}


fileprivate struct SemicirclePreview: View {
    let cases: [Semicircle.Direction] = [
        .left, .right, .full,
        .topHalf, .bottomHalf,
        .topLeading, .topTrailing,
        .bottomLeading, .bottomTrailing
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            ForEach(cases.indices, id: \.self) { i in
                Semicircle(direction: cases[i])
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)
            }
        }
        .padding()
    }
}

#Preview {
    SemicirclePreview()
}
