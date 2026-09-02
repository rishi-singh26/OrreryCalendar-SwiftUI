//
//  LargeScreenView.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI
import SwiftData

struct LargeScreenView: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    @State private var viewModel = ContentViewModel()

    var body: some View {
        ThemeReader { theme, colorScheme in
            NavigationStack {
                Group {
                    if dataController.isReady, let snapshot = dataController.snapshot(for: viewModel.selectedDate) {
                        MainContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    } else {
                        CalculatingPositionsView(theme: theme)
                    }
                }
                .background(theme.background.ignoresSafeArea())
                .toolbar {
                    ToolbarBuilder(theme: theme, colorScheme: colorScheme)
                }
                .inspector(isPresented: $viewModel.showSavedList) {
                    SavedListView { date in
                        viewModel.selectedDate = dataController.clampedDate(date)
                    }
                    .inspectorColumnWidth(min: 200, ideal: 250, max: 350)
                }
            }
        }
        .task {
            await dataController.bootstrap()
        }
        .onChange(of: dataController.isReady) { _, ready in
            viewModel.handleReadyChange(isReady: ready, dataController: dataController, rangeYears: rangeYears)
        }
    }

    @ViewBuilder
    private func MainContentBuilder(snapshot: DaySnapshot, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        VStack(spacing: 20) {
            Text(viewModel.selectedDate.formatted(.dateTime.year().month(.wide).day()))
                .font(.system(.title, design: .rounded))
                .foregroundStyle(theme.ink)
                .padding(.top)

            OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, theme: theme)
                .frame(minWidth: 600, minHeight: 600)

            Spacer(minLength: 0)

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)

            Spacer(minLength: 0)

            if viewModel.isNearRangeEdge(dataController: dataController) {
                ExtendRangeButton(theme: theme) {
                    viewModel.showSettings = true
                }
            }

            ScrubTimelineView(
                selectedDate: viewModel.dateBinding(dataController: dataController),
                minDate: dataController.startDate,
                maxDate: dataController.endDate,
                theme: theme
            )
            .padding(.bottom)
        }
        .padding(.top, 12)
    }
    
    @ToolbarContentBuilder
    private func ToolbarBuilder(theme: ThemeColors, colorScheme: ColorScheme) -> some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            ControlGroup {
                Button {
                    viewModel.selectToday(dataController: dataController)
                } label: {
                    Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
                }
                .disabled(!dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController))
                
                
                Button {
                    viewModel.showDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                }
                .disabled(!dataController.isReady)
            }
            .popover(isPresented: $viewModel.showDatePicker) {
                DatePicker(
                    "Date",
                    selection: viewModel.dateBinding(dataController: dataController),
                    in: dataController.startDate...dataController.endDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
            }
            
            
            ControlGroup {
                Button {
                    viewModel.save(dataController: dataController, modelContext: modelContext)
                } label: {
                    Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                        .foregroundStyle(viewModel.justSaved ? theme.brass : theme.ink)
                }
                .disabled(!dataController.isReady)
                
                Button {
                    viewModel.showSavedList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
            
            if dataController.isReady, let snapshot = dataController.snapshot(for: viewModel.selectedDate) {
                ControlGroup {
                    PolaroidShareButton(
                        snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, smallMoon: smallMoon, colorScheme: colorScheme
                    )
                    .labelStyle(.iconOnly)
                }
            }
            
            ControlGroup {
                Button {
                    viewModel.showSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .popover(isPresented: $viewModel.showSettings) {
                SettingsPanel()
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
