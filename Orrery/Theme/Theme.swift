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

/// Orrery-canvas-specific color tokens (orbit rings, planet dots, Saturn, the Sun's
/// halo) — split out from `ThemeColors` since these only ever apply to
/// `OrreryView`'s `Canvas` drawing, not general UI chrome.
struct OrreryPalette {
    let orbitStroke: Color
    let orbitOpacity: Double
    let planet: Color          // also the Saturn ring stroke
    let saturnBody: Color
    let sunHalo: Color
    let sunHaloOpacity: Double

    static let light = OrreryPalette(
        orbitStroke: Color(hex: 0x4E4238),
        orbitOpacity: 0.30,
        planet: Color(hex: 0x372E27),
        saturnBody: Color(hex: 0xf87c3b),
        sunHalo: Color(hex: 0xFF9658),
        sunHaloOpacity: 0.22
    )

    static let dark = OrreryPalette(
        orbitStroke: Color(hex: 0xDBC7AC),
        orbitOpacity: 0.28,
        planet: Color(hex: 0xF0E8DE),
        saturnBody: Color(hex: 0xff9d67),
        sunHalo: Color(hex: 0xFFA45C),
        sunHaloOpacity: 0.18
    )
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
    let tickMajor: Color
    let tickMinor: Color
    let tickLabel: Color
    let orrery: OrreryPalette

    static let dark = ThemeColors(
        background: Color(hex: 0x0A0A0A),
        ink: Color(hex: 0xEAE6DA),
        muted: Color(hex: 0x9C988C),
        hairline: Color(hex: 0x242420),
        brass: Color(hex: 0xC9A24A),
        brassDim: Color(hex: 0x8A6A2C),
        moonDark: Color(hex: 0x17171B),
        tickMajor: Color(hex: 0xEAE6DA, opacity: 0.45),
        tickMinor: Color(hex: 0xEAE6DA, opacity: 0.18),
        tickLabel: Color(hex: 0xEAE6DA, opacity: 0.60),
        orrery: .dark
    )

    static let light = ThemeColors(
        background: Color(hex: 0xF1EDE3),
        ink: Color(hex: 0x221F19),
        muted: Color(hex: 0x726C5C),
        hairline: Color(hex: 0xDED7C5),
        brass: Color(hex: 0x9C752F),
        brassDim: Color(hex: 0x7C5F26),
        moonDark: Color(hex: 0xDDD7C6),
        tickMajor: Color(hex: 0x221F19, opacity: 0.45),
        tickMinor: Color(hex: 0x221F19, opacity: 0.16),
        tickLabel: Color(hex: 0x221F19, opacity: 0.60),
        orrery: .light
    )

    /// The Moon disc's lit/shadowed surface colors. Fixed regardless of app appearance —
    /// unlike UI tokens such as `ink`/`moonDark`, which intentionally invert between
    /// light and dark mode, the Moon's illuminated fraction is a physical rendering and
    /// must always read as bright-lit-side/dark-shadow-side, never the reverse.
    static let moonLit = Color(hex: 0xEAE6DA)
    static let moonShadow = Color(hex: 0x17171B)

    // MARK: - Fixed accent colors (scheme-independent)
    // Colors below don't invert between light/dark mode — either they're a physical
    // rendering (the Sun always reads as warm-lit, like the Moon colors above), or a
    // fixed-chrome element (the polaroid frame is deliberately theme-independent, per
    // spec §7), or a conventional semantic (errors read red regardless of appearance).

    /// The Sun's core radial gradient — warm gold center to ember edge (spec §1),
    /// with an off-center focal point applied by the caller.
    static let sunCoreGradient = Gradient(stops: [
        .init(color: Color(hex: 0xFFF6D8), location: 0.00),  // oklch(0.99 0.05 92)
        .init(color: Color(hex: 0xFF9F52), location: 0.52),  // oklch(0.85 0.17 62)
        .init(color: Color(hex: 0xD35F2A), location: 1.00)   // oklch(0.67 0.19 44)
    ])
    /// The polaroid share card's cream frame background (spec §7) — fixed regardless
    /// of app theme, matching the physical polaroid metaphor.
    static let polaroidFrame = Color(red: 0.98, green: 0.97, blue: 0.94)
    /// The polaroid frame's hairline border stroke.
    static let polaroidStroke = Color.black.opacity(0.08)
    /// The polaroid's date caption text color.
    static let polaroidCaption = Color.black.opacity(0.75)

    /// Soft drop shadow used behind material surfaces (`withSurface(with:in:)`).
    static let surfaceShadow = Color.black.opacity(0.06)
    /// Warm glass tint behind the small-screen controls bar.
    static let controlsBarTint = Color.orange.opacity(0.1)
    /// Foreground for a disabled `GlassButton` label.
    static let disabledForeground = Color.secondary.opacity(0.7)
    /// Inline error/destructive text (e.g. settings panel data errors).
    static let errorText = Color.red

    // MARK: - Background mesh gradient
    // Precomputed static tables for BackgroundView's MeshGradient — no per-frame or
    // per-launch construction, just a lookup. Grid points are normalized 0...1,
    // row-major, top-leading to bottom-trailing. Each color entry = the scheme's base
    // composited with the warm/pale/gold radial layers at that vertex's position, per
    // the original CSS radial-gradient geometry:
    //   warm oklch(... 46) at 88% 4%,  fades to transparent at 58%
    //   pale oklch(... 88) at  6% 40%, fades to transparent at 55%
    //   gold oklch(... 96) at 34% 108%, fades to transparent at 66%

    static let meshGridPoints: [SIMD2<Float>] = [
        SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.2, 0.0), SIMD2<Float>(0.4, 0.0), SIMD2<Float>(0.6, 0.0), SIMD2<Float>(0.8, 0.0), SIMD2<Float>(1.0, 0.0),
        SIMD2<Float>(0.0, 0.2), SIMD2<Float>(0.2, 0.2), SIMD2<Float>(0.4, 0.2), SIMD2<Float>(0.6, 0.2), SIMD2<Float>(0.8, 0.2), SIMD2<Float>(1.0, 0.2),
        SIMD2<Float>(0.0, 0.4), SIMD2<Float>(0.2, 0.4), SIMD2<Float>(0.4, 0.4), SIMD2<Float>(0.6, 0.4), SIMD2<Float>(0.8, 0.4), SIMD2<Float>(1.0, 0.4),
        SIMD2<Float>(0.0, 0.6), SIMD2<Float>(0.2, 0.6), SIMD2<Float>(0.4, 0.6), SIMD2<Float>(0.6, 0.6), SIMD2<Float>(0.8, 0.6), SIMD2<Float>(1.0, 0.6),
        SIMD2<Float>(0.0, 0.8), SIMD2<Float>(0.2, 0.8), SIMD2<Float>(0.4, 0.8), SIMD2<Float>(0.6, 0.8), SIMD2<Float>(0.8, 0.8), SIMD2<Float>(1.0, 0.8),
        SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.2, 1.0), SIMD2<Float>(0.4, 1.0), SIMD2<Float>(0.6, 1.0), SIMD2<Float>(0.8, 1.0), SIMD2<Float>(1.0, 1.0),
    ]

    /// Base color behind the mesh (matches the ZStack's base fill) — light mode.
    static let meshLightBase = Color(red: 0.9411, green: 0.7333, blue: 0.5490) // oklch(0.88 0.07 68)
    /// Base color behind the mesh (matches the ZStack's base fill) — dark mode.
    static let meshDarkBase = Color(red: 0.1216, green: 0.0863, blue: 0.0627) // oklch(0.16 0.02 60)

    static let meshLightColors: [Color] = [
        Color(red: 0.9685, green: 0.8140, blue: 0.6523), Color(red: 0.9691, green: 0.8114, blue: 0.6499), Color(red: 0.9781, green: 0.7733, blue: 0.6145), Color(red: 0.9870, green: 0.7354, blue: 0.5794), Color(red: 0.9955, green: 0.6996, blue: 0.5463), Color(red: 0.9939, green: 0.7062, blue: 0.5524),
        Color(red: 0.9771, green: 0.8759, blue: 0.7437), Color(red: 0.9764, green: 0.8706, blue: 0.7360), Color(red: 0.9783, green: 0.8214, blue: 0.6761), Color(red: 0.9833, green: 0.7512, blue: 0.5941), Color(red: 0.9886, green: 0.7290, blue: 0.5735), Color(red: 0.9879, green: 0.7319, blue: 0.5762),
        Color(red: 0.9849, green: 0.9323, blue: 0.8271), Color(red: 0.9825, green: 0.9149, blue: 0.8014), Color(red: 0.9765, green: 0.8715, blue: 0.7373), Color(red: 0.9740, green: 0.8131, blue: 0.6592), Color(red: 0.9753, green: 0.7852, blue: 0.6256), Color(red: 0.9750, green: 0.7866, blue: 0.6269),
        Color(red: 0.9640, green: 0.8638, blue: 0.7069), Color(red: 0.9536, green: 0.8504, blue: 0.6727), Color(red: 0.9490, green: 0.8279, blue: 0.6370), Color(red: 0.9518, green: 0.8060, blue: 0.6144), Color(red: 0.9648, green: 0.8122, blue: 0.6439), Color(red: 0.9685, green: 0.8140, blue: 0.6523),
        Color(red: 0.9217, green: 0.7914, blue: 0.5461), Color(red: 0.9074, green: 0.7845, blue: 0.5138), Color(red: 0.9047, green: 0.7832, blue: 0.5077), Color(red: 0.9149, green: 0.7882, blue: 0.5308), Color(red: 0.9337, green: 0.7972, blue: 0.5732), Color(red: 0.9566, green: 0.8083, blue: 0.6252),
        Color(red: 0.8977, green: 0.7798, blue: 0.4916), Color(red: 0.8724, green: 0.7677, blue: 0.4345), Color(red: 0.8652, green: 0.7642, blue: 0.4179), Color(red: 0.8871, green: 0.7747, blue: 0.4676), Color(red: 0.9140, green: 0.7877, blue: 0.5287), Color(red: 0.9418, green: 0.8011, blue: 0.5917),
    ]

    static let meshDarkColors: [Color] = [
        Color(red: 0.0770, green: 0.0439, blue: 0.0204), Color(red: 0.0851, green: 0.0467, blue: 0.0202), Color(red: 0.2063, green: 0.0893, blue: 0.0177), Color(red: 0.3266, green: 0.1315, blue: 0.0153), Color(red: 0.4402, green: 0.1714, blue: 0.0129), Color(red: 0.4194, green: 0.1641, blue: 0.0133),
        Color(red: 0.1495, green: 0.1021, blue: 0.0346), Color(red: 0.1434, green: 0.0972, blue: 0.0334), Color(red: 0.1874, green: 0.0990, blue: 0.0259), Color(red: 0.2764, green: 0.1139, blue: 0.0163), Color(red: 0.3470, green: 0.1386, blue: 0.0148), Color(red: 0.3376, green: 0.1354, blue: 0.0150),
        Color(red: 0.2157, green: 0.1553, blue: 0.0475), Color(red: 0.1953, green: 0.1389, blue: 0.0435), Color(red: 0.1444, green: 0.0980, blue: 0.0336), Color(red: 0.1412, green: 0.0739, blue: 0.0227), Color(red: 0.1684, green: 0.0760, blue: 0.0185), Color(red: 0.1640, green: 0.0744, blue: 0.0186),
        Color(red: 0.1631, green: 0.1127, blue: 0.0311), Color(red: 0.1682, green: 0.1167, blue: 0.0275), Color(red: 0.1456, green: 0.0984, blue: 0.0223), Color(red: 0.1054, green: 0.0663, blue: 0.0176), Color(red: 0.0832, green: 0.0488, blue: 0.0198), Color(red: 0.0770, green: 0.0439, blue: 0.0204),
        Color(red: 0.1569, green: 0.1069, blue: 0.0126), Color(red: 0.1812, green: 0.1261, blue: 0.0102), Color(red: 0.1858, green: 0.1298, blue: 0.0097), Color(red: 0.1684, green: 0.1160, blue: 0.0114), Color(red: 0.1365, green: 0.0908, blue: 0.0146), Color(red: 0.0973, green: 0.0599, blue: 0.0184),
        Color(red: 0.1979, green: 0.1393, blue: 0.0085), Color(red: 0.2410, green: 0.1732, blue: 0.0043), Color(red: 0.2534, green: 0.1830, blue: 0.0031), Color(red: 0.2160, green: 0.1535, blue: 0.0068), Color(red: 0.1700, green: 0.1172, blue: 0.0113), Color(red: 0.1225, green: 0.0798, blue: 0.0159),
    ]
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
