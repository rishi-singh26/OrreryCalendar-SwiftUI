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
    /// (e.g. a Mac with no Force Touch trackpad). Gated by the "Haptic Feedback"
    /// setting (`AppStorageKeys.hapticsEnabled`).
    @ViewBuilder
    func hapticTick<T: Equatable>(_ trigger: T) -> some View {
        hapticFeedback(trigger: trigger) { $0 != $1 }
    }
    
    /// The single entry point for app-generated haptics: a light impact when `trigger`
    /// changes and `condition(old, new)` holds, suppressed when the user has turned off
    /// "Haptic Feedback" in Settings. Don't call `.sensoryFeedback` directly.
    func hapticFeedback<T: Equatable>(
        trigger: T,
        condition: @escaping (_ oldValue: T, _ newValue: T) -> Bool
    ) -> some View {
        modifier(HapticFeedbackModifier(trigger: trigger, condition: condition))
    }
    
    /// Thin-material list row background on iOS 18/macOS 15 (the oldest supported
    /// releases, per the project's 18.6/15.6 deployment targets); a no-op on
    /// iOS 26/macOS 26+, where lists already get the system's Liquid Glass look.
    @ViewBuilder
    func iOS18ListRowBackground() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
        } else {
            self.listRowBackground(Rectangle().fill(.thinMaterial))
        }
    }
    
    /// Clear list row background on iOS 18/macOS 15; a no-op on iOS 26/macOS 26+.
    @ViewBuilder
    func iOS18ListRowClearBackground() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
        } else {
            self.listRowBackground(Rectangle().fill(.clear))
        }
    }
}

/// Applies the app's haptic and checks the Settings toggle when the trigger changes.
/// The gate lives in the `condition` closure rather than an `if` around the modifier,
/// so the view's identity (and its `@State`) is unaffected when the setting flips.
private struct HapticFeedbackModifier<T: Equatable>: ViewModifier {
    @AppStorage(AppStorageKeys.hapticsEnabled) private var hapticsEnabled = true
    let trigger: T
    let condition: (T, T) -> Bool
    
    /// SwiftUI on macOS only maps `.alignment` and `.levelChange` to the trackpad
    /// (`NSHapticFeedbackManager`); `.impact` is silently a no-op there.
    private var feedback: SensoryFeedback {
#if os(macOS)
        .alignment
#else
        .impact(weight: .light, intensity: 1)
#endif
    }
    
    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { oldValue, newValue in
            hapticsEnabled && condition(oldValue, newValue)
        }
    }
}
