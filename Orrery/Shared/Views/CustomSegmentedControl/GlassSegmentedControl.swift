//
//  GlassSegmentedControl.swift
//  TesterApp
//
//  Created by Rishi Singh on 16/09/26.
//

import SwiftUI

struct GlassSegmentedControl: View {
    var config: Config = .init()
    @Binding var selection: Int
    @Binding var tabs: [Self.Tab]
    // View properties
    @State private var activeIndex: Int?
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var didSetInitialScrollPosition = false
    @State private var programmaticScrollTargetX: CGFloat?
    // Tracks the tab nearest the scroll view center on every scroll geometry
    // update, independent of `activeIndex`'s programmatic-scroll guard, so
    // haptics fire for every tab crossed during both a drag and a tap-driven
    // animated scroll.
    @State private var hapticIndex: Int?
    // Cached from `tabs`, recomputed only when a tab's measured size actually
    // changes (see onGeometryChange below) rather than on every scroll frame.
    @State private var cachedSnapPoints: [CGFloat] = []
    
    var body: some View {
        GeometryReader {
            let containerSize = $0.size
            let activeSize = tabs[activeIndex ?? 0].viewSize
            
            // ScrollView
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach($tabs) { $tab in
                        Text(tab.title)
                            .font(.system(size: 18))
                            .padding(.horizontal, (config.refractionDepth + 3))
                            .frame(height: containerSize.height)
                        // Retreiving view size
                            .onGeometryChange(for: CGSize.self) {
                                $0.size
                            } action: { newValue in
                                tab.viewSize = newValue
                                cachedSnapPoints = tabs.snapPoints
                                // Sizes are measured asynchronously, one tab at a time, so the
                                // initial scroll (which depends on snapPoints derived from those
                                // sizes) must wait until every tab has reported a non-zero size.
                                guard !didSetInitialScrollPosition, tabs.allSatisfy({ $0.viewSize != .zero }) else { return }
                                didSetInitialScrollPosition = true
                                let cappedIndex = max(min(selection, tabs.count - 1), 0)
                                let targetX = cachedSnapPoints[cappedIndex]
                                // Mark this as a programmatic scroll so the in-flight intermediate
                                // offsets reported by onScrollGeometryChange aren't misread as the
                                // user landing on a different tab.
                                programmaticScrollTargetX = targetX
                                scrollPosition.scrollTo(x: targetX)
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                                    selection = index
                                }
                            }
                    }
                }
                // Optional Cirremt Item Highlight with tint color
                .overlay {
                    HStack(spacing: 0) {
                        ForEach($tabs) { $tab in
                            Text(tab.title)
                                .font(.system(size: 18))
                                .foregroundStyle(config.tint)
                                .padding(.horizontal, (config.refractionDepth + 3))
                                .frame(height: containerSize.height)
                        }
                    }
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: activeSize.width, height: activeSize.height)
                            .visualEffect { content, proxy in
                                let midx = proxy.frame(in: .scrollView).midX
                                
                                return content
                                    .offset(x: -midx)
                            }
                    }
                    .allowsHitTesting(scrollPhase != .animating)
                }
                // Capsule shape
                .background(alignment: .leading) {
                    ZStack {
                        if #available(iOS 26, macOS 26, *) {
                            Capsule()
                                .fill(.clear)
                                .frame(width: activeSize.width, height: activeSize.height)
                                .glassEffect(.regular, in: .capsule)
                        } else {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .frame(width: activeSize.width, height: activeSize.height)
                        }
                    }
                    .visualEffect { content, proxy in
                        let midx = proxy.frame(in: .scrollView).midX
                        
                        return content
                            .offset(x: -midx)
                    }
                }
                .animation(
                    .interactiveSpring(response: 0.35, dampingFraction: 0.3, blendDuration: 0.4),
                    value: activeIndex
                )
            }
            .scrollIndicators(.hidden)
            // Starting and ending at center
            .safeAreaPadding(.horizontal, (containerSize.width / 2))
            .scrollTargetBehavior(CustomScrollTarget(snapPoints: cachedSnapPoints))
            .scrollPosition($scrollPosition, anchor: .center)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.x + $0.contentInsets.leading
            } action: { oldValue, newValue in
                if let index = cachedSnapPoints.closestSnapPointIndex(newValue) {
                    hapticIndex = index
                }
                // While a scroll we triggered programmatically (initial position, or a
                // tap/selection-driven snap) is still settling, its intermediate offsets
                // pass through other tabs' snap points and must not be mistaken for the
                // user having landed on a different tab.
                if let targetX = programmaticScrollTargetX {
                    if abs(newValue - targetX) < 1 {
                        programmaticScrollTargetX = nil
                    }
                    return
                }
                // `activeIndex` tracks every snap point swept over so the highlight
                // pill can morph/slide continuously during a drag. `selection` is
                // deliberately not written here — committing it per intermediate
                // crossing would flicker it through every tab a fast drag passes on
                // the way to its target (e.g. 1 -> 2 -> 3 instead of 1 -> 3), which
                // is wasteful for consumers that react to each change with
                // expensive work. It's committed once the scroll settles instead;
                // see onScrollPhaseChange.
                if let index = cachedSnapPoints.closestSnapPointIndex(newValue), activeIndex != nil {
                    activeIndex = index
                }
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                scrollPhase = newPhase
                // Commit the settled index to `selection` once the scroll comes to
                // rest from user interaction. `.animating` is the phase for our own
                // programmatic (tap-driven) scrolls, whose `selection` is already
                // committed by the tap itself before the scroll starts; excluding
                // idle-after-`.animating` here avoids clobbering that with a stale
                // `activeIndex`, which lags behind during programmatic scrolls (see
                // programmaticScrollTargetX above).
                if newPhase == .idle, oldPhase != .animating, let activeIndex {
                    selection = activeIndex
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 1), trigger: hapticIndex) { oldValue, newValue in
            oldValue != nil && newValue != nil && oldValue != newValue
        }
        .frame(height: 40)
        .task {
            if activeIndex == nil {
                let cappedIndex = max(min(selection, tabs.count - 1), 0)
                selection = cappedIndex
                activeIndex = cappedIndex
            }
        }
        .onChange(of: selection) { oldValue, newValue in
            if activeIndex != newValue {
                let cappedIndex = max(min(selection, tabs.count - 1), 0)
                let targetX = cachedSnapPoints[cappedIndex]
                programmaticScrollTargetX = targetX
                // Optional: Animation
                withAnimation(.snappy) {
                    scrollPosition.scrollTo(x: targetX)
                }
            }
        }
    }
    
    struct Config {
        var tint: Color = .yellow
        var refractionDepth: CGFloat = 17
    }
    
    struct Tab: Identifiable {
        var title: String
        fileprivate var viewSize: CGSize = .zero
        
        init(title: String) {
            self.title = title
        }
        
        var id: String { title }
    }
}

fileprivate extension [GlassSegmentedControl.Tab] {
    var snapPoints: [CGFloat] {
        var snapPoints: [CGFloat] = []
        var x: CGFloat = 0
        for tab in self {
            snapPoints.append(x + tab.viewSize.width / 2)
            x += tab.viewSize.width
        }

        return snapPoints
    }
}

fileprivate extension [CGFloat] {
    func closestSnapPoint(_ offset: CGFloat) -> CGFloat {
        self.min(by: {
            abs($0 - offset) < abs($1 - offset)
        }) ?? offset
    }

    func closestSnapPointIndex(_ offset: CGFloat) -> Int? {
        if let (index, _) = self.enumerated().min(by: {
            abs($0.element - offset) < abs($1.element - offset)
        }) {
            return index
        }
        return nil
    }
}

fileprivate struct CustomScrollTarget: ScrollTargetBehavior {
    var snapPoints: [CGFloat]
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let offset = target.rect.origin.x

        target.rect.origin.x = snapPoints.closestSnapPoint(offset)
    }
    
    // Optional: For fast declaration!
    func properties(context: PropertiesContext) -> Properties {
        var properties = Properties()
        #if !os(macOS)
        properties.limitsScrolls = true
        #endif
        return properties
    }
}

struct GlassSegmentedControlView: View {
    // View properties
    @State private var activeIndex: Int = 3
    @State private var tabs: [GlassSegmentedControl.Tab] = [
        .init(title: "Portrait"),
        .init(title: "Photo"),
        .init(title: "Video"),
        .init(title: "Panorama"),
        .init(title: "Cinematic"),
        .init(title: "Dolby Vision")
    ]
    var body: some View {
        GlassSegmentedControl(
            config: .init(tint: .red, refractionDepth: 20),
            selection: $activeIndex,
            tabs: $tabs
        )
        .onChange(of: activeIndex) { oldValue, newValue in
            print(newValue)
        }
    }
}

#Preview {
    GlassSegmentedControlView()
}
