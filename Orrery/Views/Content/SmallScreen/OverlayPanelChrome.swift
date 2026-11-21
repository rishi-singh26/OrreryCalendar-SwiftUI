//
//  OverlayPanelChrome.swift
//  Orrery
//

#if os (iOS)
import SwiftUI

/// Shared chrome for `SmallScreenView`'s date picker/saved items/settings overlay panels: a
/// fixed height, a top inset that clears the close button overlaid at `.topTrailing`, the
/// close button itself, and the panel's open/close transition. The Planets panel
/// (`PlanetDetailView`) builds its own equivalent chrome instead, since its title needs the
/// planet's own (possibly desynced) date rather than the shared `viewModel.selectedDate`.
struct OverlayPanelChrome<Content: View>: View {
    /// Top inset the panel reserves for its content, keeping it clear of the close button
    /// overlaid at `.topTrailing` — that button is a 45pt `GlassButton` plus its own
    /// `.padding()`.
    private let topInset: CGFloat = 40

    var height: CGFloat? = nil
    /// Color scheme used for the top gradient tint.
    let colorScheme: ColorScheme
    let transition: AnyTransition
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            content()
                .frame(width: width)
                .safeAreaPadding(.top, topInset)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            colorScheme == .dark
                                ? .orange.mix(with: .black, by: 0.4).opacity(0.4)
                                : .orange.mix(with: .gray, by: 0.3).opacity(0.6),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                }
                .overlay(alignment: .topTrailing) {
                    GlassButton(systemName: "xmark", size: 45, action: onClose)
                        .help("Close")
                        .accessibilityLabel("Close")
                        .padding()
                }
                .transition(transition)
        }
        .frame(height: height)
    }
}
#endif
