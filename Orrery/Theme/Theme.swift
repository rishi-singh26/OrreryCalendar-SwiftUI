//
//  Theme.swift
//  Orrery
//
//  Color tokens and appearance handling, ported 1:1 from the validated web
//  prototype (spec §1). A single brass accent is reserved for the Sun, the
//  current-date marker, and active toggle states — never introduce a second.
//

import SwiftUI

/// User-facing appearance preference, persisted via `@AppStorage`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The concrete `ColorScheme` to force via `.preferredColorScheme(_:)`, or `nil` to
    /// follow the environment (device) appearance live.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Resolved color tokens for one appearance (dark or light), matching spec §1 exactly.
struct ThemeColors {
    let background: Color
    let ink: Color
    let muted: Color
    let hairline: Color
    let brass: Color
    let brassDim: Color
    let moonDark: Color
    let orbitStroke: Color
    let tickMajor: Color
    let tickMinor: Color
    let tickLabel: Color

    static let dark = ThemeColors(
        background: Color(hex: 0x0A0A0A),
        ink: Color(hex: 0xEAE6DA),
        muted: Color(hex: 0x9C988C),
        hairline: Color(hex: 0x242420),
        brass: Color(hex: 0xC9A24A),
        brassDim: Color(hex: 0x8A6A2C),
        moonDark: Color(hex: 0x17171B),
        orbitStroke: Color(hex: 0xEAE6DA, opacity: 0.22),
        tickMajor: Color(hex: 0xEAE6DA, opacity: 0.45),
        tickMinor: Color(hex: 0xEAE6DA, opacity: 0.18),
        tickLabel: Color(hex: 0xEAE6DA, opacity: 0.60)
    )

    static let light = ThemeColors(
        background: Color(hex: 0xF1EDE3),
        ink: Color(hex: 0x221F19),
        muted: Color(hex: 0x726C5C),
        hairline: Color(hex: 0xDED7C5),
        brass: Color(hex: 0x9C752F),
        brassDim: Color(hex: 0x7C5F26),
        moonDark: Color(hex: 0xDDD7C6),
        orbitStroke: Color(hex: 0x221F19, opacity: 0.18),
        tickMajor: Color(hex: 0x221F19, opacity: 0.45),
        tickMinor: Color(hex: 0x221F19, opacity: 0.16),
        tickLabel: Color(hex: 0x221F19, opacity: 0.60)
    )

    /// The Sun's radial gradient — warm gold center to darker gold edge (spec §1).
    static let sunGradient = Gradient(colors: [
        Color(hex: 0xF6E6AE),
        Color(hex: 0xC9A24A),
        Color(hex: 0x8A6A2C),
    ])
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// Resolves the active `ThemeColors` from the persisted `AppearanceMode` plus the live
/// environment color scheme, so "System" tracks device appearance changes without
/// requiring a relaunch. Hands the resolved `ColorScheme` down alongside the colors so
/// callers that need it (e.g. the polaroid share renderer) don't have to re-derive it
/// from the environment above this point in the tree, where the mode override hasn't
/// been applied yet.
struct ThemeReader<Content: View>: View {
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @Environment(\.colorScheme) private var systemColorScheme
    let content: (ThemeColors, ColorScheme) -> Content

    init(@ViewBuilder content: @escaping (ThemeColors, ColorScheme) -> Content) {
        self.content = content
    }

    private var resolvedScheme: ColorScheme {
        appearanceMode.colorScheme ?? systemColorScheme
    }

    var body: some View {
        content(resolvedScheme == .dark ? .dark : .light, resolvedScheme)
            .preferredColorScheme(appearanceMode.colorScheme)
    }
}
