//
//  SmallScreenView.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

#if os (iOS)
import SwiftUI
import SwiftData

struct SmallScreenView: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    @State private var viewModel = ContentViewModel()
    let animation: Animation = .bouncy(duration: 0.3)

    var body: some View {
        // Looked up once per body evaluation and handed to both the main content and
        // the toolbar below, rather than each independently calling
        // `dataController.snapshot(for:)` (a `UTCDay` calendar-based lookup).
        let snapshot = dataController.snapshot(for: viewModel.selectedDate)
        ThemeReader { theme, colorScheme in
            NavigationStack {
                Group {
                    if let snapshot {
                        MainContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    } else {
                        CalculatingPositionsView(theme: theme)
                    }
                }
                .background(theme.background.ignoresSafeArea())
            }
        }
        .task {
            await dataController.bootstrap()
        }
        .onChange(of: dataController.isReady) { _, ready in
            viewModel.handleReadyChange(isReady: ready, dataController: dataController, rangeYears: rangeYears)
        }
        .onChange(of: dataController.startDate) { _, _ in
            viewModel.handleRangeChange(dataController: dataController)
        }
        .onChange(of: dataController.endDate) { _, _ in
            viewModel.handleRangeChange(dataController: dataController)
        }
    }

    @ViewBuilder
    private func MainContentBuilder(snapshot: DaySnapshot, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                SelectedDateTitleText(date: viewModel.selectedDate, color: theme.ink)
                
                OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, theme: theme, aspectRatio: 1)
                                
                MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)
                
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .onTapGesture {
                withAnimation(animation) {
                    viewModel.controlPresentationState = .none
                }
            }
            
            if #available(iOS 26.0, *) {
                BuildControllsBar(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    .clipShape(.rect(cornerRadius: 35))
                    .padding(.bottom)
                    .glassEffect(.regular, in: .rect(cornerRadius: 35))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                BuildControllsBar(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    .padding(.bottom)
                    .withSurface(in: .rect(cornerRadius: 35))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    @ViewBuilder
    private func BuildControllsBar(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        VStack(spacing: 0) {
            ZStack {
                switch viewModel.controlPresentationState {
                case .datePicker:
                    DatePicker(
                        "Date",
                        selection: viewModel.dateBinding(dataController: dataController),
                        in: dataController.startDate...dataController.endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsVisibility(.hidden)
                    .padding()
                    .frame(height: 280)
                    .transition(.blurReplace)
                case .savedItems:
                    SavedListView { date in
                        viewModel.selectedDate = dataController.clampedDate(date)
                        withAnimation(animation) {
                            viewModel.controlPresentationState = .none
                        }
                    }
                    .frame(height: 450)
                    .transition(.blurReplace)
                case .settings:
                    SettingsPanel()
                        .frame(height: 550)
                        .transition(.blurReplace)
                case .none:
                    EmptyView()
                }
            }
            .compositingGroup()
            
            if viewModel.isNearRangeEdge(dataController: dataController) {
                ExtendRangeButton(theme: theme) {
                    withAnimation(animation) {
                        viewModel.controlPresentationState = .settings
                    }
                }
            }
            
            HStack {
                GlassButton(circular: true) {
                    viewModel.selectToday(dataController: dataController)
                } label: {
                    Group {
                        if #available(iOS 26.0, *) {
                            Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
                        } else {
                            Image(systemName: "calendar.badge.clock")
                        }
                    }
                    .font(.title2)
                }
                .disabled(!dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController))
                .help("Jump to Today")
                .accessibilityLabel("Today")

                GlassButton(systemName: "calendar") {
                    withAnimation(animation) {
                        viewModel.toggleControlPresentation(.datePicker)
                    }
                }
                .disabled(!dataController.isReady)
                .help("Choose a Date")
                .accessibilityLabel("Choose Date")

                Spacer()
                
                GlassButton(circular: true) {
                    viewModel.save(dataController: dataController, modelContext: modelContext)
                } label: {
                    Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                        .font(.title2)
                        .foregroundStyle(viewModel.justSaved ? theme.brass : theme.ink)
                }
                .disabled(!dataController.isReady)
                .help(viewModel.justSaved ? "Saved" : "Save This View")
                .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
                
                GlassButton(systemName: "list.bullet") {
                    withAnimation(animation) {
                        viewModel.toggleControlPresentation(.savedItems)
                    }
                }
                .help("Show Saved Views")
                .accessibilityLabel("Saved Views")

                if let snapshot {
                    PolaroidShareButton(
                        snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, smallMoon: smallMoon, colorScheme: colorScheme
                    )
                    .labelStyle(.iconOnly)
                    .help("Share This View")
                }

                GlassButton(systemName: "slider.horizontal.3") {
                    withAnimation(animation) {
                        viewModel.toggleControlPresentation(.settings)
                    }
                }
                .help("Settings")
                .accessibilityLabel("Settings")
            }
            .padding(20)
            
            // `ScrubTimelineView`'s animated tick fade gets visibly laggy once the
            // cached range spans more than ±10 years — the no-animation variant trades
            // that fade for scrolling that stays smooth at any range size (see
            // `ScrubTimelineNoAnimationView`).
            if rangeYears > viewModel.rangeYearsForAnimatedScrubber {
                ScrubTimelineNoAnimationView(
                    selectedDate: viewModel.dateBinding(dataController: dataController),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )
            } else {
                ScrubTimelineView(
                    selectedDate: viewModel.dateBinding(dataController: dataController),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(DataController(modelContainer: try! ModelContainer(
            for: PlanetDataStore.self, SavedSnapshot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
}
#endif
