//
//  NotchEdge.swift
//  Orrery
//
//  Created by Rishi Singh on 08/09/26.
//

/// Which screen edge the notch is glued to. The flat, wide edge of the shape
/// sits flush against this edge and the body protrudes inward from it.
enum NotchEdge: CaseIterable, Hashable {
    case top, bottom, leading, trailing

    var title: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .leading: return "Left"
        case .trailing: return "Right"
        }
    }
}
