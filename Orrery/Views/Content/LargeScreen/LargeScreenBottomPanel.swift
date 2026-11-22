//
//  LargeScreenBottomPanel.swift
//  Orrery
//

import SwiftUI

/// `LargeScreenView`'s bottom panel: the "extend range" affordance above either the Planets
/// panel or the scrub timeline. The surrounding glass/clip/padding is applied by the caller.
struct LargeScreenBottomPanel: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let viewModel: ContentViewModel
    let snapshot: DaySnapshot?
    let theme: ThemeColors
    let presentSettings: () -> Void
    
    var body: some View {
        VStack {
            if viewModel.isNearRangeEdge(dataController: dataController) {
                ExtendRangeButton(theme: theme) {
                    presentSettings()
                }
            }
            
            ZStack {
                if viewModel.showPlanetsView {
                    PlanetDetailView(
                        selectedDate: viewModel.dateBinding(dataController: dataController),
                        theme: theme,
                        onClose: {
                            withAnimation(viewModel.effectiveAnimation(reduceMotion: reduceMotion)) {
                                viewModel.showPlanetsView.toggle()
                            }
                        }
                    )
                    .transition(viewModel.effectiveTransition(reduceMotion: reduceMotion))
                }
                
                // Kept mounted only once `snapshot` exists — same as `SmallScreenView`'s
                // scrub timeline — so its one-shot initial-position setup (see
                // `ScrubTimelineView`/`ScrubTimelineNoAnimationView`) always sees the
                // cached range's final `minDate`/`maxDate`, not the placeholder values
                // `DataController` reports before it's ready.
                if snapshot != nil {
                    DateScrubTimeline(
                        selectedDate: viewModel.dateBinding(dataController: dataController),
                        minDate: dataController.startDate,
                        maxDate: dataController.endDate,
                        theme: theme
                    )
                    .opacity(!viewModel.showPlanetsView ? 1 : 0)
                    .allowsHitTesting(!viewModel.showPlanetsView)
                    .accessibilityHidden(viewModel.showPlanetsView)
                    .padding(.vertical, 8)
                } else {
                    VStack {
                        
                    }
                    .frame(height: 64)
                }
            }
        }
    }
}
