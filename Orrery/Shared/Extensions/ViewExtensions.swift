//
//  ViewExtensions.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI

extension View {
    
#if os(iOS) || os(macOS)
    
    @ViewBuilder
    func withSurface<S: Shape>(with material: Material = .thinMaterial, in shape: S) -> some View {
        self.background {
            shape
                .fill(material)
                .shadow(color: .black.opacity(0.06), radius: 3, x: -1, y: -3)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 1, y: 3)
        }
    }
#endif
    
    
    /// Sheet on iPhone, popover on iPad/macOS, and a bottom ornament on visionOS —
    /// the same adaptive treatment as `orrerySettingsPresentation`, but displaying
    /// caller-supplied content instead of the fixed `SettingsPanel`. The `width`
    /// and `height` size the popover/ornament; the iPhone sheet lets its content
    /// determine its own height.
    @ViewBuilder
    func withInspectorOrOrnament<Content: View>(
        isPresented: Binding<Bool>,
        inspectorWidth: CGFloat = 250,
        ornamentSize: CGSize = .init(width: 360, height: 420),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if os(macOS)
        self.inspector(isPresented: isPresented) {
            content()
                .inspectorColumnWidth(min: inspectorWidth, ideal: inspectorWidth, max: inspectorWidth)
        }
#elseif os(visionOS)
        self.ornament(
            visibility: isPresented.wrappedValue ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom)
        ) {
            content().frame(width: ornamentSize.width, height: ornamentSize.height)
        }
#else
        self
#endif
    }

    /// `.sensoryFeedback` itself degrades to a no-op on hardware without haptics (e.g. a
    /// Mac with no Force Touch trackpad), but on visionOS the modifier is unavailable
    /// entirely before visionOS 26 — this falls back to doing nothing on those OS
    /// versions instead of failing to build.
    @ViewBuilder
    func hapticTick<T: Equatable>(_ trigger: T) -> some View {
#if os(visionOS)
        if #available(visionOS 26.0, *) {
            self.sensoryFeedback(.impact(weight: .light, intensity: 1), trigger: trigger)
        } else {
            self
        }
#else
        self.sensoryFeedback(.impact(weight: .light, intensity: 1), trigger: trigger)
#endif
    }

}
