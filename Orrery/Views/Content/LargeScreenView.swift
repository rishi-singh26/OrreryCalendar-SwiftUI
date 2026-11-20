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
    @Environment(\.scenePhase) private var scenePhase
#if os(macOS)
    @Environment(\.openSettings) private var openSettings
#endif
    
    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears
    @AppStorage(AppStorageKeys.autoPlayEnabled) private var autoPlayEnabled = true
    @AppStorage(AppStorageKeys.autoPlayRate) private var autoPlayRate: AutoPlayRate = AutoPlayRate.defaultRate
    @AppStorage(AppStorageKeys.autoPlayDirection) private var autoPlayDirection: AutoPlayDirection = AutoPlayDirection.defaultDirection
    
    /// Persisted, normalized (`0...1`) position of the trailing-edge Moon-size
    /// scrubber — same `AppStorageKeys.moonSizeScrub` key `SmallScreenView` uses, so
    /// the two layouts share one persisted position. Kept here (rather than in
    /// `ContentViewModel`) since `@AppStorage` only integrates with SwiftUI's
    /// view-update machinery when it's declared directly on a `View`; see
    /// `SmallScreenView`'s matching property for the full rationale.
    @AppStorage(AppStorageKeys.moonSizeScrub) private var moonSizeScrub: Double = 0.5
    
    @State private var viewModel = ContentViewModel()
    
    /// `animation`, softened when Reduce Motion is on — used at every call
    /// site that changes `viewModel.controlPresentationState`.
    private var effectiveAnimation: Animation {
        reduceMotion ? viewModel.reducedAnimation : viewModel.animation
    }
    
    /// Play/Pause for Auto Play. Its settings live in the main Settings panel.
    private var autoPlayButton: some View {
        let isPlaying = viewModel.autoPlay.isPlaying
        
        return Button {
            withAnimation(effectiveAnimation) {
                viewModel.toggleAutoPlay(dataController: dataController)
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .disabled(!dataController.isReady)
        .help(isPlaying ? "Pause Auto Play" : "Start Auto Play")
        .accessibilityLabel("Auto play")
        .accessibilityValue(isPlaying ? "Playing" : "Paused")
    }
    
    /// The overlay panels' open/close transition — `.blurReplace` normally, a
    /// plain fade when Reduce Motion is on to match `effectiveAnimation`.
    private var panelTransition: AnyTransition {
        reduceMotion ? viewModel.reducedTransition : viewModel.transition
    }
    
    private var moonSizeScrubBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(moonSizeScrub) },
            set: { moonSizeScrub = Double($0) }
        )
    }
    
    /// The size multiplier `MoonPhaseRow` reads — the actual `moonSizeScrub` →
    /// multiplier mapping is pure business logic, so it lives on `viewModel`
    /// (shared with `SmallScreenView`, not duplicated).
    private var moonSizeMultiplier: CGFloat {
        viewModel.moonSizeMultiplier(forScrub: moonSizeScrub)
    }
    
    /// The trailing-edge notch the Moon-size scrubber is docked in — mirrors
    /// `SmallScreenView`'s matching shape so the two layouts share one tuned look.
    private var moonSizeScrubberNotchShape: WedgedNotchShape {
        WedgedNotchShape(
            edge: .trailing,
            topCornerRadius: 60,
            wedgeInset: 12,
            outerCornerRadius: 20,
            topCurveFactor: 0.73,
            topCurveDepth: 45
        )
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
                        MainContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme, size: proxy.size)
                    }
#if os(macOS)
                    .frame(minWidth: 460, minHeight: 700)
#endif
                }
                .padding([.horizontal, .bottom], 5)
                .toolbar {
                    ToolbarBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                }
                .withInspector(isPresented: $viewModel.showSavedList) {
                    SavedListView { date in
                        viewModel.jumpToDate(date, dataController: dataController)
                    }
                }
            }
        }
        .task {
            await dataController.bootstrap()
        }
        // `initial: true` because the controller is shared across windows: a window
        // opened after it's already ready never sees these values change, so it must
        // seed its selection and range thresholds from the current values on mount.
        .onChange(of: autoPlayEnabled) { _, enabled in
            if !enabled { viewModel.autoPlay.stop() }
        }
        .onChange(of: autoPlayRate, initial: true) { _, newValue in viewModel.autoPlay.rate = newValue }
        .onChange(of: autoPlayDirection, initial: true) { _, newValue in viewModel.autoPlay.direction = newValue }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.autoPlay.stop() }
        }
        .onDisappear {
            viewModel.autoPlay.stop()
        }
        .onChange(of: dataController.isReady, initial: true) { _, ready in
            viewModel.handleReadyChange(isReady: ready, dataController: dataController, rangeYears: rangeYears)
        }
        .onChange(of: dataController.startDate, initial: true) { _, _ in
            viewModel.handleRangeChange(dataController: dataController)
        }
        .onChange(of: dataController.endDate, initial: true) { _, _ in
            viewModel.handleRangeChange(dataController: dataController)
        }
    }
    
    @ViewBuilder
    private func MainContentBuilder(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 20) {
                SelectedDateTitleText(date: viewModel.selectedDate)
                    .padding([.top, .leading])
                
                let isWide = size.width > size.height
                let layout: AnyLayout = isWide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
                
                layout {
                    if isWide {
                        Spacer()
                    }
                    // Always mounted — `OrreryView` shows its own loading pose (planets
                    // lined up left of their orbits) while `snapshot` is nil, then eases
                    // into place once it arrives, rather than the chart not appearing
                    // at all until data is ready.
                    OrreryView(
                        snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, theme: theme,
                        aspectRatio: 1, dateChangeAnimationTrigger: viewModel.dateChangeAnimationTrigger
                    )
                    
                    Spacer()
                    
                    if let snapshot {
                        MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, theme: theme, sizeMultiplier: moonSizeMultiplier, horizontal: !isWide)
                    }
                    
                    if isWide {
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 100)
            
            
            
            moonSizeScrubberNotchShape
                .fill(.background)
                .frame(width: 35, height: 220)
                .overlay {
                    // Drives `moonSizeMultiplier` (via `moonSizeScrub`), which
                    // `MoonPhaseRow` below animates into on change. Padded and
                    // clipped to the notch's straight-walled middle so the ruler
                    // never travels into its flared top/bottom corners.
                    VerticalScrubber(
                        value: moonSizeScrubBinding,
                        tickCount: 30,
                        visibleTickCount: 12,
                        tickThickness: 2,
                        tickLength: 16,
                        dimColor: theme.ink.opacity(0.5),
                        accentColor: .accentColor,
                        accessibilityLabel: "Moon size"
                    )
                    .frame(height: 160)
                    .padding(.horizontal, 10)
                }
                .clipShape(moonSizeScrubberNotchShape)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            
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
                                withAnimation(effectiveAnimation) {
                                    viewModel.showPlanetsView.toggle()
                                }
                            }
                        )
                        //.frame(height: size.height)
                        .transition(panelTransition)
                    }
                    
                    // Kept mounted only once `snapshot` exists — same as `SmallScreenView`'s
                    // scrub timeline — so its one-shot initial-position setup (see
                    // `ScrubTimelineView`/`ScrubTimelineNoAnimationView`) always sees the
                    // cached range's final `minDate`/`maxDate`, not the placeholder values
                    // `DataController` reports before it's ready.
                    if snapshot != nil {
                        Group {
                            // `ScrubTimelineView`'s animated tick fade gets visibly laggy once the
                            // cached range spans more than ±10 years, regardless of platform — the
                            // no-animation variant trades that fade for scrolling that stays smooth
                            // at any range size (see `ScrubTimelineNoAnimationView`).
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
                        .opacity(!viewModel.showPlanetsView ? 1 : 0)
                        .allowsHitTesting(!viewModel.showPlanetsView)
                        .accessibilityHidden(viewModel.showPlanetsView)
                        .padding(.vertical, 8)
                    } else {
                        EmptyView()
                            .frame(height: 64)
                    }
                }
            }
            .glassOrSurface(glass: .tinted(ThemeColors.controlsBarTint), in: .rect(cornerRadius: 15))
            .clipShape(.rect(cornerRadius: 15))
            .padding(5)
        }
    }
    
    @ToolbarContentBuilder
    private func ToolbarBuilder(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some ToolbarContent {
        // Planets and AutoPlay
        ToolbarItemGroup(placement: .primaryAction) {
            if autoPlayEnabled {
                autoPlayButton
            }
            
            if #available(iOS 26.0, macOS 26.0, *) {
                Button {
                    withAnimation(effectiveAnimation) {
                        viewModel.showPlanetsView.toggle()
                    }
                } label: {
                    Text("Planets")
                        .font(.caption)
                        .monospaced()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button {
                    withAnimation(effectiveAnimation) {
                        viewModel.showPlanetsView.toggle()
                    }
                } label: {
                    Text("Planets")
                        .font(.caption)
                        .monospaced()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        
        // Today and Calendar
        ToolbarItemGroup(placement: .navigation) {
            Button {
                viewModel.selectToday(dataController: dataController)
            } label: {
                if #available(iOS 26.0, macOS 26.0, *) {
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
                VStack(spacing: 8) {
#if os (macOS)
                    MonthYearSelector(
                        selection: viewModel.animatedDateBinding(dataController: dataController),
                        minDate: dataController.startDate,
                        maxDate: dataController.endDate
                    )
                    
                    MacCalendarView(
                        selection: viewModel.animatedDateBinding(dataController: dataController),
                        minDate: dataController.startDate,
                        maxDate: dataController.endDate,
                        today: dataController.todayDate,
                        theme: theme
                    )
#else
                    DatePicker(
                        "Date",
                        selection: viewModel.animatedDateBinding(dataController: dataController),
                        in: dataController.startDate...dataController.endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
#endif
                }
                .padding()
                .frame(minWidth: DeviceType.isIpad ? 320 : nil, minHeight: DeviceType.isIpad ? 320 : nil)
            }
        }
        
        // Save and List
        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                viewModel.save(dataController: dataController, modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                    .foregroundStyle(viewModel.justSaved ? theme.brass : theme.ink)
            }
            .disabled(!dataController.isReady)
            .help(viewModel.justSaved ? "Saved" : "Save This View")
            .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
            
            if DeviceType.isIpad {
                Button {
                    viewModel.showSavedList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Show Saved Views")
                .accessibilityLabel("Saved Views")
                .popover(isPresented: $viewModel.showSavedList) {
                    SavedListView { date in
                        viewModel.jumpToDate(date, dataController: dataController)
                    }
                    .frame(minHeight: DeviceType.isIpad ? 450 : 360)
                    .frame(minWidth: 320, idealWidth: 360)
                }
            } else {
                Button {
                    viewModel.showSavedList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Show Saved Views")
                .accessibilityLabel("Saved Views")
            }
        }
        
        // Share and Settings
        ToolbarItemGroup(placement: .principal) {
            if let snapshot {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
            }
            
            Button {
                presentSettings(toggle: true)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Settings")
            .accessibilityLabel("Settings")
            .popover(isPresented: $viewModel.showSettings) {
                SettingsPanel()
            }
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
        .environment(DataController(modelContainer: try! ModelContainer(
            for: PlanetDataStore.self, SavedSnapshot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
}
