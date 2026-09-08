//
//  VerticalScrubber.swift
//  Orrery
//
//  A vertical tick-ruler scrubber, built on the same visual/interaction language
//  as `ScrubTimelineView`'s horizontal date ruler — a row of tick marks where the
//  one(s) nearest the current position grow and turn accent-colored, the rest sit
//  short and dim, animated via the same `animationRange`-between-old-and-new-index
//  approach (so a fast drag ripples the highlight across every tick it swept
//  through, not just the endpoint). Turned 90° and driven by a direct `DragGesture`
//  rather than a `ScrollView`, since this is a small, fixed-size control, not a
//  scrollable timeline spanning years.
//
//  The one behavioral difference from `ScrubTimelineView`: that view only taps a
//  haptic at month boundaries, since day-to-day ticks aren't individually
//  meaningful there. Here every tick is equally meaningful (there's no larger unit
//  to reserve the feedback for), so a haptic fires on every tick the drag crosses.
//
//  Deliberately knows nothing about what it controls, so it's reusable anywhere a
//  continuous vertical control is needed — first used to drive the animated
//  Moon-size control docked in `SmallScreenView`'s trailing-edge notch.
//

import SwiftUI

struct VerticalScrubber: View {
    /// Normalized scrubber position, clamped to `0...1`. `0` is the bottom tick,
    /// `1` the top — updated continuously as the drag progresses, not just when it
    /// ends, same as `ScrubTimelineView`.
    @Binding var value: CGFloat

    /// The ruler is divided into `tickCount` intervals (`tickCount + 1` ticks
    /// total, one per gridline including both ends).
    var tickCount: Int = 16
    var tickThickness: CGFloat = 2
    var tickLength: CGFloat = 16
    var minorLengthProgress: CGFloat = 0.55
    var dimColor: Color = .primary.opacity(0.3)
    var accentColor: Color = .accentColor
    /// Accessibility label announced for the control, e.g. "Moon size".
    var accessibilityLabel: String = "Scrubber"

    private let animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)

    @State private var currentIndex: Int = 0
    @State private var animationRange: ClosedRange<Int> = 0...0
    @State private var isDragging = false

    /// Bumped on every tick crossed while dragging, applied via `.hapticTick(_:)`
    /// (a no-op on hardware without haptics).
    @State private var hapticTick = 0

    private func index(forValue v: CGFloat) -> Int {
        Int((min(max(v, 0), 1) * CGFloat(tickCount)).rounded())
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height

            VStack(spacing: 0) {
                ForEach(0...tickCount, id: \.self) { index in
                    tickView(index)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        guard height > 0 else { return }
                        let clampedY = min(max(drag.location.y, 0), height)
                        value = 1 - (clampedY / height)

                        let newIndex = index(forValue: value)
                        guard newIndex != currentIndex else { return }
                        let isGreater = newIndex > currentIndex
                        animationRange = (isGreater ? currentIndex : newIndex)...(isGreater ? newIndex : currentIndex)
                        currentIndex = newIndex
                        hapticTick += 1
                    }
                    .onEnded { _ in
                        isDragging = false
                        animationRange = currentIndex...currentIndex
                    }
            )
        }
        .frame(width: tickLength)
        .onAppear {
            currentIndex = index(forValue: value)
            animationRange = currentIndex...currentIndex
        }
        .onChange(of: value) { _, newValue in
            guard !isDragging else { return }
            currentIndex = index(forValue: newValue)
            animationRange = currentIndex...currentIndex
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(min(max(value, 0), 1) * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 1 / CGFloat(tickCount)
            switch direction {
            case .increment: value = min(value + step, 1)
            case .decrement: value = max(value - step, 0)
            @unknown default: break
            }
        }
        .hapticTick(hapticTick)
    }

    @ViewBuilder
    private func tickView(_ index: Int) -> some View {
        // Ticks are laid out top (index `tickCount`, value `1`) to bottom (index
        // `0`, value `0`), matching `value`'s bottom-is-0/top-is-1 convention.
        let isInside = animationRange.contains(tickCount - index)
        let lengthProgress: CGFloat = isInside ? 1 : minorLengthProgress

        Rectangle()
            .fill(isInside ? accentColor : dimColor)
            .frame(width: tickLength * lengthProgress, height: tickThickness)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(isInside ? .none : animation, value: isInside)
    }
}

#Preview("Vertical Scrubber") {
    @Previewable @State var value: CGFloat = 0.5
    VStack {
        Text("\(Int(value * 100))%")
        VerticalScrubber(value: $value)
            .frame(height: 220)
    }
    .padding()
}
