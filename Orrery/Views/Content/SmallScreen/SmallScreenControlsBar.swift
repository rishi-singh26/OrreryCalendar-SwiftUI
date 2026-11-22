//
//  SmallScreenControlsBar.swift
//  Orrery
//

#if os (iOS)
import SwiftUI

/// `SmallScreenView`'s bottom control bar: the scrubber/controls row, plus whichever overlay
/// panel `viewModel.controlPresentationState` selects, plus the "extend range" affordance.
/// The surrounding glass/clip/padding is applied by the caller.
struct SmallScreenControlsBar: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let datePickerWheelHeight: CGFloat = 280
    
    let viewModel: ContentViewModel
    let snapshot: DaySnapshot?
    let theme: ThemeColors
    let colorScheme: ColorScheme
    
    private var effectiveAnimation: Animation {
        viewModel.effectiveAnimation(reduceMotion: reduceMotion)
    }
    
    private var panelTransition: AnyTransition {
        viewModel.effectiveTransition(reduceMotion: reduceMotion)
    }
    
    private func dismissPanel() {
        withAnimation(effectiveAnimation) {
            viewModel.controlPresentationState = .none
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Always mounted — shown/hidden via `.opacity`, never inserted or
                // removed by the switch below. See `scrubberAndControls`'s
                // doc comment for why that distinction matters.
                scrubberAndControls
                    .padding(.bottom)
                    .opacity(viewModel.controlPresentationState == .none ? 1 : 0)
                    .allowsHitTesting(viewModel.controlPresentationState == .none)
                    .accessibilityHidden(viewModel.controlPresentationState != .none)
                
                switch viewModel.controlPresentationState {
                case .datePicker:
                    panel(height: datePickerWheelHeight) {
                        DatePicker(
                            "Date",
                            selection: viewModel.animatedDateBinding(dataController: dataController),
                            in: dataController.startDate...dataController.endDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .padding(.horizontal)
                        .labelsHidden()
                    }
                case .savedItems:
                    panel {
                        SavedListView { date in
                            viewModel.jumpToDate(date, dataController: dataController)
                            dismissPanel()
                        }
                        .scrollContentBackground(.hidden)
                    }
                case .settings:
                    panel {
                        SettingsPanel()
                            .scrollContentBackground(.hidden)
                    }
                case .planets:
                    PlanetDetailView(
                        selectedDate: viewModel.dateBinding(dataController: dataController),
                        theme: theme,
                        onClose: { dismissPanel() }
                    )
                    .transition(panelTransition)
                case .none:
                    EmptyView()
                }
            }
            .compositingGroup()
            
            if viewModel.isNearRangeEdge(dataController: dataController) && viewModel.controlPresentationState != .settings {
                ExtendRangeButton(theme: theme) {
                    withAnimation(effectiveAnimation) {
                        viewModel.controlPresentationState = .settings
                    }
                }
                .transition(panelTransition)
            }
        }
    }
    
    private func panel<Content: View>(height: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        SmallScreenPanelChrome(
            height: height,
            colorScheme: colorScheme,
            transition: panelTransition,
            onClose: { dismissPanel() },
            content: content
        )
    }
    
    /// Calendar/buttons capsules plus the scrub timeline. Kept mounted at all
    /// times (shown/hidden via `.opacity`) rather than being one case of the
    /// presentation-state switch: switching it in and out on every
    /// date-picker/saved-items/settings open used to reset the scrub timeline's
    /// `@State` — recomputing its month-tick index and re-running its brief
    /// setup delay on every single panel close, which was visibly laggy.
    private var scrubberAndControls: some View {
        VStack(spacing: 0) {
            HStack {
                SmallScreenCalendarCapsule(viewModel: viewModel)
                    .glassOrSurface(glass: .interactive, in: .capsule)
                
                Spacer()
                
                SmallScreenButtonsCapsule(viewModel: viewModel, snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    .glassOrSurface(glass: .interactive, in: .capsule)
            }
            .padding(10)
            
            if snapshot != nil {
                DateScrubTimeline(
                    selectedDate: viewModel.dateBinding(dataController: dataController),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )
            } else {
                VStack {
                    
                }
                .frame(height: 64)
            }
        }
    }
}
#endif
