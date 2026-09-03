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
