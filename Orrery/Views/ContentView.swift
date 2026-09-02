//
//  ContentView.swift
//  Orrery
//
//  Root composition (spec §5–§7): the orrery chart, Moon phase row, scrub timeline, and
//  toolbar (date picker, save, saved list, share, settings). Adapts chrome per platform
//  where noted; the core layout is shared.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    @State private var selectedDate = UTCDay.todayAsUTCMidnight()
    @State private var hasInitializedSelection = false
    @State private var showSettings = false
    @State private var showDatePicker = false
    @State private var justSaved = false

    var body: some View {
        ThemeReader { theme, colorScheme in
            NavigationStack {
                Group {
                    if dataController.isReady, let snapshot = dataController.snapshot(for: selectedDate) {
                        mainContent(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    } else {
                        loadingView(theme: theme)
                    }
                }
                .background(theme.background.ignoresSafeArea())
                .navigationTitle("Orrery")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbarContent(theme: theme, colorScheme: colorScheme) }
                .orrerySettingsPresentation(isPresented: $showSettings)
                .sheet(isPresented: $showDatePicker) {
                    DatePickerSheet(
                        selectedDate: $selectedDate,
                        minDate: dataController.startDate,
                        maxDate: dataController.endDate
                    )
                }
            }
        }
        .task {
            await dataController.bootstrap()
        }
        .onChange(of: dataController.isReady) { _, ready in
            guard ready else { return }
            if !hasInitializedSelection {
                selectedDate = dataController.clampedDate(dataController.todayDate)
                hasInitializedSelection = true
            }
            dataController.resumeRangeIfNeeded(desiredYears: rangeYears)
        }
    }

    @ViewBuilder
    private func mainContent(snapshot: DaySnapshot, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        VStack(spacing: 20) {
            OrreryView(snapshot: snapshot, showOrbits: showOrbits, theme: theme)
                .padding(.horizontal)

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text(selectedDate.formatted(.dateTime.year().month(.wide).day()))
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(theme.ink)

                ScrubTimelineView(
                    selectedDate: Binding(
                        get: { selectedDate },
                        set: { selectedDate = dataController.clampedDate($0) }
                    ),
                    minDate: dataController.startDate,
                    maxDate: dataController.endDate,
                    theme: theme
                )

                if isNearRangeEdge {
                    Button("Extend the cached range in Settings") {
                        showSettings = true
                    }
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(theme.brass)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
    }

    private func loadingView(theme: ThemeColors) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(theme.brass)
            Text("Calculating planetary positions…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Within 30 days of either edge of the cached range — a reasonable trigger to
    /// surface the "extend range" affordance rather than silently auto-extending
    /// (spec §5 allows either; this keeps compute triggers explicit/user-visible).
    private var isNearRangeEdge: Bool {
        guard dataController.isReady else { return false }
        let toStart = (try? UTCDay.dayCount(from: dataController.startDate, to: selectedDate)) ?? .max
        let toEnd = (try? UTCDay.dayCount(from: selectedDate, to: dataController.endDate)) ?? .max
        return toStart < 30 || toEnd < 30
    }

    private var isAlreadyOnToday: Bool {
        UTCDay.midnight(of: selectedDate) == dataController.clampedDate(dataController.todayDate)
    }

    @ToolbarContentBuilder
    private func toolbarContent(theme: ThemeColors, colorScheme: ColorScheme) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Today") {
                selectedDate = dataController.clampedDate(dataController.todayDate)
            }
            .disabled(!dataController.isReady || isAlreadyOnToday)
        }

        ToolbarItem(placement: .cancellationAction) {
            Button {
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .disabled(!dataController.isReady)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            saveButton(theme: theme)

            NavigationLink {
                SavedListView { date in
                    selectedDate = dataController.clampedDate(date)
                }
            } label: {
                Image(systemName: "list.bullet")
            }

            if dataController.isReady, let snapshot = dataController.snapshot(for: selectedDate) {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, smallMoon: smallMoon, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
            }

            Button {
                // Toggle (not just set true) so this button also dismisses on
                // visionOS, where the settings ornament has no swipe/tap-outside
                // dismissal the way the sheet/popover on other platforms do.
                showSettings.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    private func saveButton(theme: ThemeColors) -> some View {
        Button {
            save()
        } label: {
            Image(systemName: justSaved ? "checkmark" : "bookmark")
                .foregroundStyle(justSaved ? theme.brass : theme.ink)
        }
        .disabled(!dataController.isReady)
    }

    private func save() {
        guard let snapshot = dataController.snapshot(for: selectedDate) else { return }
        let saved = SavedSnapshot(date: snapshot.date, moonPhaseDeg: snapshot.moonPhaseDeg, planets: snapshot.planets)
        modelContext.insert(saved)
        withAnimation {
            justSaved = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation {
                justSaved = false
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
