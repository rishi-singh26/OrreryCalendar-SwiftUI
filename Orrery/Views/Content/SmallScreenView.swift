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
    let animation: Animation = .spring(duration: 0.3)

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
                    .padding(.bottom)
                    .clipShape(.rect(cornerRadius: 35))
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
                if #available(iOS 26.0, *) {
                    BuildCalendarCapsule()
                        .clipShape(.capsule)
                        .glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    BuildCalendarCapsule()
                        .withSurface(in: .capsule)
                }

                Spacer()
                
                if #available(iOS 26.0, *) {
                    BuildButtonsCapsule(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                        .clipShape(.capsule)
                        .glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    BuildButtonsCapsule(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                        .withSurface(in: .capsule)
                }
            }
            .padding()
            
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
    
    @ViewBuilder
    private func BuildCalendarCapsule() -> some View {
        let isTodayButtonDisabled = !dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController)
        HStack(spacing: 20) {
            Button {
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
            .disabled(isTodayButtonDisabled)
            .help("Jump to Today")
            .accessibilityLabel("Today")
            .foregroundStyle(isTodayButtonDisabled ? .tertiary : .primary)
            
            Button {
                withAnimation(animation) {
                    viewModel.toggleControlPresentation(.datePicker)
                }
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
            }
            .disabled(!dataController.isReady)
            .help("Choose a Date")
            .accessibilityLabel("Choose Date")
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func BuildButtonsCapsule(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        HStack(spacing: 20) {
            Button {
                viewModel.save(dataController: dataController, modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                    .font(.title2)
                    .foregroundStyle(viewModel.justSaved ? .accentColor : theme.ink)
            }
            .disabled(!dataController.isReady)
            .help(viewModel.justSaved ? "Saved" : "Save This View")
            .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
            .foregroundStyle(.primary)
            
            Button {
                withAnimation(animation) {
                    viewModel.toggleControlPresentation(.savedItems)
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
            .help("Show Saved Views")
            .accessibilityLabel("Saved Views")
            .foregroundStyle(.primary)
            
            Divider()
                .frame(height: 25)
            
            if let snapshot {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, smallMoon: smallMoon, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
                .foregroundStyle(.primary)
            }

            Button {
                withAnimation(animation) {
                    viewModel.toggleControlPresentation(.settings)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
            }
            .help("Settings")
            .accessibilityLabel("Settings")
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 11)
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
