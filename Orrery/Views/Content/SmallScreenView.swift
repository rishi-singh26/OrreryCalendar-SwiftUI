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
                .toolbar { ToolbarContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme) }
                .sheet(isPresented: $viewModel.showSettings) {
                    SettingsSheet()
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
            SelectedDateTitleText(date: viewModel.selectedDate, color: theme.ink)

            OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, theme: theme, aspectRatio: 1)

            Spacer(minLength: 0)

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)

            Spacer(minLength: 0)

            if viewModel.isNearRangeEdge(dataController: dataController) {
                ExtendRangeButton(theme: theme) {
                    viewModel.showSettings = true
                }
            }

            if #available(iOS 26.0, *) {
                ScrubTimelineView(
                    selectedDate: viewModel.dateBinding(dataController: dataController),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )
                .clipShape(.rect(cornerRadius: 20))
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 20))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            } else {
                ScrubTimelineView(
                    selectedDate: viewModel.dateBinding(dataController: dataController),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )
                .withSurface(in: .rect(cornerRadius: 20))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 12)
    }

    @ToolbarContentBuilder
    private func ToolbarContentBuilder(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                viewModel.selectToday(dataController: dataController)
            } label: {
                if #available(iOS 26.0, *) {
                    Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
                } else {
                    Image(systemName: "calendar.badge.clock")
                }
            }
            .disabled(!dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController))
            .help("Jump to Today")
            .accessibilityLabel("Today")

            Button {
                viewModel.showDatePicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .disabled(!dataController.isReady)
            .help("Choose a Date")
            .accessibilityLabel("Choose Date")
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
                .frame(minWidth: 320, minHeight: 320)
                .presentationCompactAdaptation(.popover)
            }

            Spacer()
        }

        ToolbarItemGroup(placement: .bottomBar) {
            saveButton(theme: theme)

            NavigationLink {
                SavedListView { date in
                    viewModel.selectedDate = dataController.clampedDate(date)
                }
            } label: {
                Image(systemName: "list.bullet")
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

            Button {
                // Toggle (not just set true) so tapping this button again also
                // dismisses the settings sheet.
                viewModel.showSettings.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Settings")
            .accessibilityLabel("Settings")
        }
    }

    private func saveButton(theme: ThemeColors) -> some View {
        Button {
            viewModel.save(dataController: dataController, modelContext: modelContext)
        } label: {
            Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                .foregroundStyle(viewModel.justSaved ? theme.brass : theme.ink)
        }
        .disabled(!dataController.isReady)
        .help(viewModel.justSaved ? "Saved" : "Save This View")
        .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
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
