//
//  BackgroundView.swift
//  Orrery
//
//  Created by Rishi Singh on 08/09/26.
//

import SwiftUI

/// Mesh-gradient background from the Orrery refresh, using MeshGradient (iOS 18+/macOS 15+).
/// Grid points and colours both live in `ThemeColors` as precomputed static tables — no
/// per-frame or per-launch construction, just a lookup.
struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeshGradient(
            width: 6,
            height: 6,
            points: ThemeColors.meshGridPoints,
            colors: colorScheme == .light ? ThemeColors.meshLightColors : ThemeColors.meshDarkColors,
            background: colorScheme == .light ? ThemeColors.meshLightBase : ThemeColors.meshDarkBase,
            smoothsColors: true
        )
    }
}

#Preview {
    BackgroundView()
}
