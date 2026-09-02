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
                .toolbar { ToolbarContentBuilder(theme: theme, colorScheme: colorScheme) }
                .orrerySettingsPresentation(isPresented: $viewModel.showSettings)
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
                .font(.system(.title, design: .serif))
                .foregroundStyle(theme.ink)

            OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, theme: theme, aspectRatio: 1)

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
            .clipShape(.rect(cornerRadius: 20))
            .withOSSurface(with: .regular.interactive(), in: .rect(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
    }

    @ToolbarContentBuilder
    private func ToolbarContentBuilder(theme: ThemeColors, colorScheme: ColorScheme) -> some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                viewModel.selectToday(dataController: dataController)
            } label: {
                Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
            }
            .disabled(!dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController))
            .help("Jump to Today")
            .accessibilityLabel("Today")

            DatePicker(
                "Select Date",
                selection: viewModel.dateBinding(dataController: dataController),
                in: dataController.startDate...dataController.endDate,
                displayedComponents: .date
            )
            .labelsHidden()
            // Hide the selected-date chip while keeping the picker tappable,
            .colorMultiply(.clear)
            // then apply fixed width.
            .frame(width: 25)
            // then draw the calendar icon on top as the only visible affordance.
            .overlay {
                Image(systemName: "calendar")
                    .allowsHitTesting(false)
            }
            .presentationCompactAdaptation(.popover)
            .disabled(!dataController.isReady)
            .help("Choose a Date")

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

            if dataController.isReady, let snapshot = dataController.snapshot(for: viewModel.selectedDate) {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, smallMoon: smallMoon, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
            }

            Button {
                // Toggle (not just set true) so this button also dismisses on
                // visionOS, where the settings ornament has no swipe/tap-outside
                // dismissal the way the sheet/popover on other platforms do.
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
