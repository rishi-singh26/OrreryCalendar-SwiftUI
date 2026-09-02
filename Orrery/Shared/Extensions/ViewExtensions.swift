//
//  ViewExtensions.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI

extension View {
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

    /// Sheet on iPhone, popover on iPad/macOS, and a bottom ornament on visionOS —
    /// the same adaptive treatment as `orrerySettingsPresentation`, but displaying
    /// caller-supplied content instead of the fixed `SettingsPanel`. The `width`
    /// and `height` size the popover/ornament; the iPhone sheet lets its content
    /// determine its own height.
    @ViewBuilder
    func orreryResponsivePresentation<Content: View>(
        isPresented: Binding<Bool>,
        width: CGFloat = 360,
        height: CGFloat = 420,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        self.popover(isPresented: isPresented, arrowEdge: .bottom) {
            content().frame(width: width, height: height)
        }
        #elseif os(visionOS)
        self.ornament(
            visibility: isPresented.wrappedValue ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom)
        ) {
            content().frame(width: width, height: height)
        }
        #else
        self.modifier(
            AdaptiveResponsivePresentation(
                isPresented: isPresented,
                width: width,
                height: height,
                content: content
            )
        )
        #endif
    }
}


#if os(iOS)
private struct AdaptiveResponsivePresentation<PresentedContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: () -> PresentedContent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content.popover(isPresented: $isPresented) {
                self.content().frame(width: width, height: height)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                self.content()
            }
        }
    }
}
#endif

