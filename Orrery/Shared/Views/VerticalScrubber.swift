//
//  VerticalScrubber.swift
//  Orrery
//
//  A vertical tick-ruler scrubber, built on the same visual/interaction language
//  as `ScrubTimelineView`'s horizontal date ruler — a view-aligned, snap-to-tick
//  `ScrollView` where the tick(s) nearest the centered selection grow tall and
//  turn accent-colored, the rest sit short and dim, animated via the same
//  `animationRange`-between-old-and-new-index approach (so a fast scroll ripples
//  the highlight across every tick it swept through, not just the endpoint).
//  Turned 90° and driven by a vertical `ScrollView` rather than the horizontal
//  one `ScrubTimelineView` uses — see that file's comments for why each scroll/
//  animation piece is shaped the way it is; this mirrors it tick-for-tick, just
//  keyed by a normalized `CGFloat` position instead of a `Date`.
//
//  `tickCount` ticks make up the full ruler, but only `visibleTickCount` are
//  ever visible at once — the rest scroll into view, with `tickSlotHeight`
//  (`containerHeight / visibleTickCount`, measured live) sizing each tick's
//  slot so exactly `visibleTickCount` fill whatever height the caller gives
//  this view.
//
//  The one behavioral difference from `ScrubTimelineView`: that view only taps a
//  haptic at month boundaries, since day-to-day ticks aren't individually
//  meaningful there. Here every tick is equally meaningful (there's no larger unit
//  to reserve the feedback for), so a haptic fires on every tick the scroll
//  settles on.
//
//  Deliberately knows nothing about what it controls, so it's reusable anywhere a
//  continuous vertical control is needed — first used to drive the animated
//  Moon-size control docked in `SmallScreenView`'s trailing-edge notch.
//

import SwiftUI

struct VerticalScrubber: View {
    /// Normalized scrubber position, clamped to `0...1`. `0` is the bottom tick,
    /// `1` the top — updated continuously as the scroll progresses, not just when
    /// it ends, same as `ScrubTimelineView`.
    @Binding var value: CGFloat

    /// Total number of ticks in the ruler (the full scrollable range).
    var tickCount: Int
    /// How many ticks are visible in the control's height at once — the rest
    /// scroll into view. Drives `tickSlotHeight` (`containerHeight / visibleTickCount`).
    var visibleTickCount: Int
    var tickThickness: CGFloat
    var tickLength: CGFloat
    var minorLengthProgress: CGFloat
    var dimColor: Color
    var accentColor: Color
    /// Accessibility label announced for the control, e.g. "Moon size".
    var accessibilityLabel: String

    private let animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)

    @State private var scrollIndex: Int
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var animationRange: ClosedRange<Int>
    @State private var isInitialSetupDone = false

    /// Height available to lay the ruler out in — measured via `.onGeometryChange`
    /// rather than wrapping the `ScrollView` in a `GeometryReader` (which greedily
    /// claims all proposed space and adds a separate layout pass of its own).
    @State private var containerHeight: CGFloat = 0

    /// Bumped on every tick the scroll settles on, applied via `.hapticTick(_:)`
    /// (a no-op on hardware without haptics).
    @State private var hapticTick = 0

    /// Seeds the scroll position at `value` synchronously — rather than leaving
    /// `scrollIndex`/`scrollPosition`/`animationRange` at placeholder defaults for
    /// `.task` to correct asynchronously after the first frame — so the ruler
    /// renders already positioned on mount instead of visibly snapping there a
    /// frame or two later. Mirrors `ScrubTimelineView.init`.
    init(
        value: Binding<CGFloat>,
        tickCount: Int = 30,
        visibleTickCount: Int = 12,
        tickThickness: CGFloat = 1.5,
        tickLength: CGFloat = 18,
        minorLengthProgress: CGFloat = 0.55,
        dimColor: Color = .primary.opacity(0.3),
        accentColor: Color = .accentColor,
        accessibilityLabel: String = "Scrubber"
    ) {
        self._value = value
        self.tickCount = tickCount
        self.visibleTickCount = visibleTickCount
        self.tickThickness = tickThickness
        self.tickLength = tickLength
        self.minorLengthProgress = minorLengthProgress
        self.dimColor = dimColor
        self.accentColor = accentColor
        self.accessibilityLabel = accessibilityLabel

        let safeIndex = Self.displayIndex(forValue: value.wrappedValue, tickCount: tickCount)
        _scrollIndex = State(initialValue: safeIndex)
        _scrollPosition = State(initialValue: safeIndex)
        _animationRange = State(initialValue: safeIndex...safeIndex)
    }

    /// The highest valid tick index — ticks run `0...maxIndex`.
    private var maxIndex: Int {
        max(tickCount - 1, 1)
    }

    /// Vertical space each tick occupies — sized so exactly `visibleTickCount`
    /// ticks fill `containerHeight`, the rest scrolling into view.
    private var tickSlotHeight: CGFloat {
        containerHeight > 0 ? containerHeight / CGFloat(visibleTickCount) : 0
    }

    /// Converts a normalized `0...1` value into a display index — ticks are laid
    /// out top (index `0`, value `1`) to bottom (index `maxIndex`, value `0`),
    /// matching `value`'s bottom-is-0/top-is-1 convention.
    private static func displayIndex(forValue v: CGFloat, tickCount: Int) -> Int {
        let maxIndex = max(tickCount - 1, 1)
        let valueIndex = Int((min(max(v, 0), 1) * CGFloat(maxIndex)).rounded())
        return maxIndex - valueIndex
    }

    private func displayIndex(forValue v: CGFloat) -> Int {
        Self.displayIndex(forValue: v, tickCount: tickCount)
    }

    private func value(forDisplayIndex index: Int) -> CGFloat {
        let valueIndex = maxIndex - index
        return CGFloat(valueIndex) / CGFloat(maxIndex)
    }

    private var accessibilityValueText: String {
        let clamped = min(max(value, 0), 1)
        let percent = Int(clamped * 100)
        return "\(percent) percent"
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(0...maxIndex, id: \.self) { index in
                    tickView(index)
                }
            }
            .frame(width: tickLength)
            .contentShape(.rect)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // Centering the first/last tick under the selection point.
        .safeAreaPadding(.vertical, max((containerHeight - tickSlotHeight) / 2, 0))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newHeight in
            let isFirstMeasurement = containerHeight == 0 && newHeight > 0
            containerHeight = newHeight
            guard isFirstMeasurement else { return }

            // `scrollPosition` was seeded to `scrollIndex` back in `init`, before
            // `containerHeight` (and the centering `safeAreaPadding` derived from
            // it) was known — the scroll view resolved that initial position
            // against zero padding, so the persisted tick lands off-center once
            // the real padding is known. Reassigning `scrollPosition` to the same
            // index it already holds is a no-op, so clear it first to force the
            // scroll view to re-resolve the anchor now that the padding is
            // correct, then restore it on the next run-loop turn.
            scrollPosition = nil
            Task { @MainActor in
                scrollPosition = scrollIndex
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y + $0.contentInsets.top
        } action: { oldValue, newValue in
            guard scrollPhase != .idle, tickSlotHeight > 0 else { return }
            let index = max(min(Int((newValue / tickSlotHeight).rounded()), maxIndex), 0)
            let previousScrollIndex = scrollIndex
            scrollIndex = index

            let isGreater = scrollIndex > previousScrollIndex
            let leadingBound = isGreater ? previousScrollIndex : scrollIndex
            let trailingBound = !isGreater ? previousScrollIndex : scrollIndex
            animationRange = leadingBound...trailingBound
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            scrollPhase = newPhase
            animationRange = scrollIndex...scrollIndex

            // In some rare instances the view aligned target behaviour will not
            // center the item; this works it out.
            if newPhase == .idle && scrollPosition != scrollIndex {
                withAnimation(animation) {
                    scrollPosition = scrollIndex
                }
            }
        }
        .frame(width: tickLength)
        .task {
            guard !isInitialSetupDone else { return }

            // Initial scroll position is seeded synchronously in `init` (see its
            // doc comment) — this just holds interaction off for a beat so the
            // view-aligned scroll target settles before it's hit-testable.
            try? await Task.sleep(for: .seconds(0.05))
            isInitialSetupDone = true
        }
        // Enabling interaction only after the initial setup is done
        .allowsHitTesting(isInitialSetupDone)
        .onChange(of: scrollIndex) { oldValue, newValue in
            Task {
                applySelection(forDisplayIndex: newValue)
            }
        }
        .onChange(of: value) { oldValue, newValue in
            let newIndex = displayIndex(forValue: newValue)
            guard scrollIndex != newIndex else { return }
            updateScrollPosition(for: newValue)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValueText)
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 1 / CGFloat(maxIndex)
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
        let isInside = animationRange.contains(index)
        let lengthProgress: CGFloat = isInside ? 1 : minorLengthProgress

        Rectangle()
            .fill(isInside ? accentColor : dimColor)
            .frame(width: tickLength * lengthProgress, height: tickThickness)
            .frame(width: tickLength, height: tickSlotHeight)
            .animation(isInside || !isInitialSetupDone ? .none : animation, value: isInside)
    }

    private func updateScrollPosition(for newValue: CGFloat) {
        let safeIndex = displayIndex(forValue: newValue)
        scrollPosition = safeIndex
        scrollIndex = safeIndex
        animationRange = safeIndex...safeIndex
    }

    /// Applies a scroll-driven index change to `value`, clamped implicitly by the
    /// ruler only ever containing indices `0...maxIndex`.
    private func applySelection(forDisplayIndex newIndex: Int) {
        let candidate = value(forDisplayIndex: newIndex)
        guard candidate != value else { return }
        value = candidate
        hapticTick += 1
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
