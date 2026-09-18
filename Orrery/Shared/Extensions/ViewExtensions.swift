//
//  ViewExtensions.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI

/// The Liquid Glass tint/interactivity a `glassOrSurface(...)` call site wants.
/// `Glass` itself is iOS 26/macOS 26+ (see `glassOrSurface`'s doc comment for why
/// it can't appear directly in that function's signature), so this is the
/// version-independent stand-in callers configure instead.
struct GlassStyle {
    var tint: Color?
    var interactive: Bool

    static let plain = GlassStyle(tint: nil, interactive: false)
    static let interactive = GlassStyle(tint: nil, interactive: true)
    static func tinted(_ color: Color) -> GlassStyle { GlassStyle(tint: color, interactive: false) }
    static func tintedInteractive(_ color: Color) -> GlassStyle { GlassStyle(tint: color, interactive: true) }
}

extension View {

#if os(iOS) || os(macOS)

    @ViewBuilder
    func withSurface<S: Shape>(with material: Material = .thickMaterial, in shape: S) -> some View {
        self.background {
            shape
                .fill(material)
                .shadow(color: ThemeColors.surfaceShadow, radius: 3, x: -1, y: -3)
                .shadow(color: ThemeColors.surfaceShadow, radius: 2, x: 1, y: 3)
        }
    }

    /// Liquid Glass (`glassEffect`) on iOS 26/macOS 26+, falling back to
    /// `withSurface`'s material-behind-a-shape treatment on earlier OS versions —
    /// the `if #available(iOS 26.0, macOS 26.0, *) { glassEffect... } else { withSurface... }`
    /// branch that used to be duplicated at every glass-or-material call site.
    /// `glass` takes a `GlassStyle`, not a bare `Glass`, because `Glass` is itself
    /// gated to iOS 26/macOS 26+ — spelling it in this function's own signature
    /// would force this whole wrapper (and every unconditional caller) behind the
    /// same availability check, defeating the point of hiding it in here.
    @ViewBuilder
    func glassOrSurface<S: Shape>(
        glass: GlassStyle = .plain,
        material: Material = .thinMaterial,
        in shape: S
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let base: Glass = glass.interactive ? .regular.interactive() : .regular
            self.glassEffect(glass.tint.map { base.tint($0) } ?? base, in: shape)
        } else {
            self.withSurface(with: material, in: shape)
        }
    }
#endif

    
    /// Shows `content` in a macOS inspector; a no-op on other platforms, where
    /// callers are expected to present `content` some other way (e.g. a sheet)
    /// when `isPresented` becomes true. The `inspectorWidth` sizes the
    /// inspector column.
    @ViewBuilder
    func withInspector<Content: View>(
        isPresented: Binding<Bool>,
        inspectorWidth: CGFloat = 250,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if os(macOS)
        self.inspector(isPresented: isPresented) {
            content()
                .inspectorColumnWidth(min: inspectorWidth, ideal: inspectorWidth, max: inspectorWidth)
        }
#else
        self
#endif
    }

    /// `.sensoryFeedback` degrades to a no-op on hardware without haptics
    /// (e.g. a Mac with no Force Touch trackpad).
    @ViewBuilder
    func hapticTick<T: Equatable>(_ trigger: T) -> some View {
        self.sensoryFeedback(.impact(weight: .light, intensity: 1), trigger: trigger)
    }

}
