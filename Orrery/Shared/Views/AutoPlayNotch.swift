//
//  AutoPlayNotch.swift
//  Orrery
//
//  Leading-edge notch holding the auto play Play/Pause capsule — the mirror of the
//  trailing Moon-size scrubber notch. Only mounted while the "Enable Auto Play"
//  setting is on, so when it's off none of this (including the `@AppStorage`
//  observers below) exists in the view hierarchy.
//

import SwiftUI

struct AutoPlayNotch: View {
    let autoPlay: AutoPlayController
    let isEnabled: Bool
    let animation: Animation
    let onToggle: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.autoPlayRate) private var rate: AutoPlayRate = AutoPlayRate.defaultRate
    @AppStorage(AppStorageKeys.autoPlayDirection) private var direction: AutoPlayDirection = AutoPlayDirection.defaultDirection

    /// Same tuned parameters as the trailing Moon-size notch (`SmallScreenView`/
    /// `LargeScreenView.moonSizeScrubberNotchShape`), just attached to the leading edge.
    private var notchShape: WedgedNotchShape {
        WedgedNotchShape(
            edge: .leading,
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
            .frame(width: 35, height: 220)
            .overlay {
                playPauseButton
            }
            .clipShape(notchShape)
            .onChange(of: rate, initial: true) { _, newValue in autoPlay.rate = newValue }
            .onChange(of: direction, initial: true) { _, newValue in autoPlay.direction = newValue }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { autoPlay.stop() }
            }
    }

    /// Unrotated button size; the rotated container below swaps these dimensions so
    /// layout and hit-testing both see a vertical capsule.
    private let buttonLength: CGFloat = 60

    private var playPauseButton: some View {
        let isPlaying = autoPlay.isPlaying

        let toggle = {
            withAnimation(animation) { onToggle() }
        }
        let label = Text(isPlaying ? "Pause" : "Play")
            .font(.caption)
            .monospaced()
            .contentTransition(.interpolate)
            .frame(width: buttonLength)

        return Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                Button(action: toggle) { label }
                    .buttonStyle(.glassProminent)
            } else {
                Button(action: toggle) { label }
                    .buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(.accentColor)
        .fixedSize()
        .rotationEffect(.degrees(-90))
        .frame(width: 28, height: buttonLength + 20)
        .disabled(!isEnabled)
        .help(isPlaying ? "Pause Auto Play" : "Start Auto Play")
        .accessibilityLabel("Auto play")
        .accessibilityValue(isPlaying ? "Playing" : "Paused")
    }
}
