//
//  VerticalGlassSegmentedControl.swift
//  Orrery
//
//  A vertical sibling of `GlassSegmentedControl`: a scrolling column of equally sized
//  text slots with a fixed glass capsule at the center that highlights the slot
//  snapped under it. Because every slot has the same known size there is no tab
//  measuring or custom snap-point logic — a view-aligned `ScrollView` does the snapping,
//  and the centering inset is a constant, so the initial position is correct from the
//  first frame.
//
//  `selection` is only written when the scroll comes to rest (or a slot is tapped), not
//  for every slot a fast drag sweeps over, since consumers may react to each change.
//

import SwiftUI

struct VerticalGlassSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    var accessibilityLabel: String
    var accessibilityValue: (Value) -> String
    var slotHeight: CGFloat
    var visibleCount: Int
    var pillWidth: CGFloat

    /// Index of the slot currently under the capsule — follows the scroll live.
    @State private var activeIndex: Int
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var hapticCount = 0

    init(
        options: [Value],
        selection: Binding<Value>,
        title: @escaping (Value) -> String,
        accessibilityLabel: String = "Selection",
        accessibilityValue: ((Value) -> String)? = nil,
        slotHeight: CGFloat = 32,
        visibleCount: Int = 5,
        pillWidth: CGFloat = 26
    ) {
        self.options = options
        self._selection = selection
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue ?? title
        self.slotHeight = slotHeight
        self.visibleCount = visibleCount
        self.pillWidth = pillWidth

        // Seeded synchronously (the centering inset below is constant) so the control
        // renders already positioned rather than snapping there after the first frame.
        let index = options.firstIndex(of: selection.wrappedValue) ?? 0
        _activeIndex = State(initialValue: index)
        _scrollPosition = State(initialValue: index)
    }

    private var containerHeight: CGFloat { slotHeight * CGFloat(visibleCount) }

    var body: some View {
        ZStack {
            pill
                .frame(width: pillWidth, height: slotHeight - 4)
                .allowsHitTesting(false)

            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(title(options[index]))
                            .font(.caption2.monospaced())
                            .fontWeight(.semibold)
                            .foregroundStyle(index == activeIndex ? Color.white : Color.secondary)
                            .animation(.easeOut(duration: 0.15), value: activeIndex)
                            .frame(maxWidth: .infinity)
                            .frame(height: slotHeight)
                            .contentShape(.rect)
                            .onTapGesture { select(index) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrollPosition, anchor: .center)
            // Centering the first/last slot under the capsule.
            .safeAreaPadding(.vertical, (containerHeight - slotHeight) / 2)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, offset in
                guard scrollPhase != .idle else { return }
                activeIndex = clamped(Int((offset / slotHeight).rounded()))
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                scrollPhase = newPhase
                guard newPhase == .idle else { return }
                // Commit the settled slot only for a user-driven scroll; our own animated
                // scrolls (tap / external change) already committed `selection`.
                if oldPhase != .animating, options.indices.contains(activeIndex),
                   options[activeIndex] != selection {
                    selection = options[activeIndex]
                }
                // In rare cases the view-aligned behavior doesn't land exactly centered.
                if scrollPosition != activeIndex {
                    withAnimation(.snappy) { scrollPosition = activeIndex }
                }
            }
        }
        .frame(height: containerHeight)
        .onChange(of: activeIndex) { _, _ in
            if scrollPhase == .interacting || scrollPhase == .decelerating {
                hapticCount += 1
            }
        }
        .onChange(of: selection) { _, newValue in
            // Selection changed from outside (e.g. Settings): follow it.
            guard let index = options.firstIndex(of: newValue), index != activeIndex else { return }
            activeIndex = index
            withAnimation(.snappy) { scrollPosition = index }
        }
        .hapticTick(hapticCount)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(options.indices.contains(activeIndex) ? accessibilityValue(options[activeIndex]) : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(clamped(activeIndex + 1))
            case .decrement: select(clamped(activeIndex - 1))
            @unknown default: break
            }
        }
    }

    @ViewBuilder
    private var pill: some View {
        if #available(iOS 26, macOS 26, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(.accentColor), in: .capsule)
        } else {
            Capsule()
                .fill(Color.accentColor)
        }
    }

    private func clamped(_ index: Int) -> Int {
        max(min(index, options.count - 1), 0)
    }

    /// Selects the slot at `index` and scrolls it under the capsule.
    private func select(_ index: Int) {
        guard options.indices.contains(index) else { return }
        activeIndex = index
        selection = options[index]
        withAnimation(.snappy) { scrollPosition = index }
    }
}

#Preview("Vertical Glass Segmented Control") {
    @Previewable @State var selection = "1W"
    VerticalGlassSegmentedControl(
        options: ["1D", "2D", "3D", "1W", "2W", "1M", "2M"],
        selection: $selection,
        title: { $0 },
        accessibilityLabel: "Speed"
    )
    .frame(width: 35)
    .padding()
}
