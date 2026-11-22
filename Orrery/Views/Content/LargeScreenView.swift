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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
#endif

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    @AppStorage(AppStorageKeys.autoPlayEnabled) private var autoPlayEnabled = true

    /// Persisted, normalized (`0...1`) position of the trailing-edge Moon-size
    /// scrubber — same `AppStorageKeys.moonSizeScrub` key `SmallScreenView` uses, so
    /// the two layouts share one persisted position. Kept here (rather than in
    /// `ContentViewModel`) since `@AppStorage` only integrates with SwiftUI's
    /// view-update machinery when it's declared directly on a `View`.
    @AppStorage(AppStorageKeys.moonSizeScrub) private var moonSizeScrub: Double = 0.5

    @State private var viewModel = ContentViewModel()

    /// The size multiplier `MoonPhaseRow` reads — the actual `moonSizeScrub` →
    /// multiplier mapping is pure business logic, so it lives on `viewModel`
    /// (shared with `SmallScreenView`, not duplicated).
    private var moonSizeMultiplier: CGFloat {
        viewModel.moonSizeMultiplier(forScrub: moonSizeScrub)
    }

    var body: some View {
        // Looked up once per body evaluation and handed to both the main content and
        // the toolbar below, rather than each independently calling
        // `dataController.snapshot(for:)` (a `UTCDay` calendar-based lookup).
        let snapshot = dataController.snapshot(for: viewModel.selectedDate)
        ThemeReader { theme, colorScheme in
            NavigationStack {
                ZStack {
                    BackgroundView()
                        .cornerRadius(20)

                    GeometryReader { proxy in
                        MainContentBuilder(snapshot: snapshot, theme: theme, size: proxy.size)
                    }
#if os(macOS)
                    .frame(minWidth: 450, minHeight: 700)
#endif
                }
                .padding([.horizontal, .bottom], 5)
                .toolbar {
                    LargeScreenToolbar(
                        viewModel: viewModel,
                        dataController: dataController,
                        modelContext: modelContext,
                        snapshot: snapshot,
                        theme: theme,
                        colorScheme: colorScheme,
                        showOrbits: showOrbits,
                        showLabels: showLabels,
                        showSunHalo: showSunHalo,
                        autoPlayEnabled: autoPlayEnabled,
                        animation: viewModel.effectiveAnimation(reduceMotion: reduceMotion),
                        toggleSettings: { presentSettings(toggle: true) }
                    )
                }
                .withInspector(isPresented: $viewModel.showSavedList) {
                    SavedListView { date in
                        viewModel.jumpToDate(date, dataController: dataController)
                    }
                }
            }
        }
        // `.includingCurrentState` because the controller is shared across windows: a window
        // opened after it's already ready never sees these values change, so it must
        // seed its selection and range thresholds from the current values on mount.
        .contentLifecycle(viewModel: viewModel, observing: .includingCurrentState)
    }

    @ViewBuilder
    private func MainContentBuilder(snapshot: DaySnapshot?, theme: ThemeColors, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            LargeScreenChartArea(
                viewModel: viewModel, snapshot: snapshot, theme: theme, size: size,
                showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo,
                moonSizeMultiplier: moonSizeMultiplier
            )

            // Drives `moonSizeMultiplier` (via `moonSizeScrub`), which `MoonPhaseRow`
            // animates into on change.
            MoonSizeScrubberNotch(scrub: $moonSizeScrub, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(y: 150)

            LargeScreenBottomPanel(
                viewModel: viewModel, snapshot: snapshot, theme: theme,
                presentSettings: { presentSettings() }
            )
            .glassOrSurface(glass: .tinted(ThemeColors.controlsBarTint), in: .rect(cornerRadius: 15))
            .clipShape(.rect(cornerRadius: 15))
            .padding(5)
        }
    }
}

private extension LargeScreenView {
    /// macOS shows Settings in its own window (⌘,); iPad keeps the popover.
    func presentSettings(toggle: Bool = false) {
        #if os(macOS)
        openSettings()
        #else
        viewModel.showSettings = toggle ? !viewModel.showSettings : true
        #endif
    }
}

#Preview {
    ContentView()
        .environment(DataController(modelContainer: try! ModelContainerFactory.make(inMemory: true)))
}
