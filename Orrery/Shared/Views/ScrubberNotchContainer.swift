//
//  ScrubberNotchContainer.swift
//  Orrery
//
//  The wedged-notch shell shared by `MoonSizeScrubberNotch` (leading edge) and
//  `AutoPlaySpeedNotch` (trailing edge): the notch shape, the show/hide animation and
//  the clipping of its content. Placement (padding/frame/offset) is left to each caller
//  since it differs per layout.
//

import SwiftUI

struct ScrubberNotchContainer<Content: View>: View {
    /// The side of the screen the notch is docked to, in layout terms (`.leading` /
    /// `.trailing`) — i.e. the same side the caller aligns it to, which flips in
    /// right-to-left layouts, while `NotchEdge` is physical.
    let side: HorizontalEdge
    /// Whether the notch is shown. It stays mounted either way: hiding animates its depth
    /// down to `0` (flattening into the edge) and showing animates it back out, rather than
    /// the view being inserted/removed.
    let isPresented: Bool
    /// Padded and clipped to the notch's straight-walled middle (`160pt` tall) so the
    /// content never travels into its flared top/bottom corners.
    @ViewBuilder let content: Content

    private let notchDepth: CGFloat = 35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    private var notchShape: WedgedNotchShape {
        let isLeftToRight = layoutDirection == .leftToRight
        let docksLeft = (side == .leading) == isLeftToRight
        return WedgedNotchShape(
            edge: docksLeft ? .leading : .trailing,
            topCornerRadius: 60,
            wedgeInset: 12,
            outerCornerRadius: 20,
            topCurveFactor: 0.73,
            topCurveDepth: 45
        )
    }

    var body: some View {
        notchShape
            .fill(.background)
            .frame(width: isPresented ? notchDepth : 0, height: 220)
            .overlay {
                content
                    .frame(height: 160)
                    // The content fades with the collapse and, once hidden, is neither
                    // touchable nor exposed to VoiceOver.
                    .opacity(isPresented ? 1 : 0)
                    .allowsHitTesting(isPresented)
                    .accessibilityHidden(!isPresented)
            }
            .clipShape(notchShape)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.35), value: isPresented)
    }
}
