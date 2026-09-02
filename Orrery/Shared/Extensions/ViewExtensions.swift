//
//  ViewExtensions.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI

extension View {
    
#if os(iOS) || os(macOS)
    /// A glass card/capsule background for popup and toast content. MapGIS's
    /// deployment floor (26.5) is already above the Liquid Glass availability
    /// floor on every platform it ships, so unlike DigipinManager's
    /// `withOSSurface` (which still supports an iOS 18 floor) this needs no
    /// `#available`/`#if os` fallback branch.
    @ViewBuilder
    func withOSSurface<S: Shape>(with glass: Glass = .regular, in shape: S) -> some View {
#if os(iOS)
        if #available(iOS 26, *) {
            self.glassEffect(glass, in: shape)
        } else {
            self.background {
                shape
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 3, x: -1, y: -3)
                    .shadow(color: .black.opacity(0.06), radius: 2, x: 1, y: 3)
            }
        }
#else
        self.background {
            shape
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 3, x: -1, y: -3)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 1, y: 3)
        }
#endif
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
        size: CGSize = .init(width: 360, height: 420),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
#if os(macOS)
        self.inspector(isPresented: isPresented) {
            content()
                .inspectorColumnWidth(min: size.width, ideal: size.width, max: size.width)
        }
#elseif os(visionOS)
        self.ornament(
            visibility: isPresented.wrappedValue ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom)
        ) {
            content().frame(width: size.width, height: size.height)
        }
#else
        self
#endif
    }
    
}
