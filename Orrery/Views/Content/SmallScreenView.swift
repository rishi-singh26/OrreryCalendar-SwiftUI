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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    @State private var viewModel = ContentViewModel()
    let animation: Animation = .spring(duration: 0.3)

    /// Normalized (`0...1`) position of the trailing-edge Moon-size scrubber. `0.5`
    /// (its default) maps to `1.0` via `moonSizeMultiplier`, reproducing
    /// `MoonPhaseRow`'s normal size until the user drags it.
    @State private var moonSizeScrub: CGFloat = 0.5

    /// Maps `moonSizeScrub`'s `0...1` range onto a size multiplier for `MoonPhaseRow`,
    /// centered so the scrubber's default (`0.5`) leaves the Moon discs at their
    /// normal size (`1.0`); the low end scales them down to 55%, the high end up to
    /// 125% — capped below the notch's own size so the Moon never grows past it.
    private var moonSizeMultiplier: CGFloat {
        0.55 + moonSizeScrub * 0.7
    }

    /// The trailing-edge notch the Moon-size scrubber is docked in — factored out
    /// so its `.fill` and `.clipShape` uses (see `MainContentBuilder`) share one
    /// set of tuned parameters instead of risking them drifting apart.
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

    private let panelCornerRadius: CGFloat = 35
    private let panelHeight: CGFloat = 450
    private let datePickerWheelHeight: CGFloat = 280
    /// Top inset the overlay panels (date picker/saved items/settings) reserve
    /// for their content, keeping it clear of the close button overlaid at
    /// `.topTrailing` — that button is a 45pt `GlassButton` plus its own
    /// `.padding()` (see `BuildCloseOverlayButton`).
    private let panelTopInset: CGFloat = 40
    private let barOuterPadding: CGFloat = 10

    /// `animation`, softened when Reduce Motion is on — used at every call
    /// site that changes `viewModel.controlPresentationState`.
    private var effectiveAnimation: Animation {
        reduceMotion ? .linear(duration: 0.1) : animation
    }

    /// The overlay panels' open/close transition — `.blurReplace` normally, a
    /// plain fade when Reduce Motion is on to match `effectiveAnimation`.
    private var panelTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(.blurReplace)
    }

    var body: some View {
        // Looked up once per body evaluation and handed to both the main content and
        // the toolbar below, rather than each independently calling
        // `dataController.snapshot(for:)` (a `UTCDay` calendar-based lookup).
        let snapshot = dataController.snapshot(for: viewModel.selectedDate)
        ThemeReader { theme, colorScheme in
            ZStack {
                BackgroundView()
                    .cornerRadius(40)
                    .padding(.horizontal, (barOuterPadding / 2))
                    .padding(.bottom, (barOuterPadding / 2) + 20)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                MainContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                
                if snapshot == nil {
                    CalculatingPositionsView(theme: theme)
                        .glassOrSurface(in: .rect(cornerRadius: panelCornerRadius))
                }
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
    private func MainContentBuilder(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                SelectedDateTitleText(date: viewModel.selectedDate, color: theme.ink)
                
                if let snapshot {
                    OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, theme: theme, aspectRatio: 1)
                    
                    MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, theme: theme, sizeMultiplier: moonSizeMultiplier)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .onTapGesture {
                withAnimation(effectiveAnimation) {
                    viewModel.controlPresentationState = .none
                }
            }
            
            moonSizeScrubberNotchShape
                .fill(.background)
                .frame(width: 40, height: 220)
                .overlay {
                    // Drives `moonSizeMultiplier` (via `moonSizeScrub`), which
                    // `MoonPhaseRow` above animates into on change. Padded and
                    // clipped to the notch's straight-walled middle so the ruler
                    // never travels into its flared top/bottom corners.
                    VerticalScrubber(
                        value: $moonSizeScrub,
                        tickCount: 16,
                        tickThickness: 2,
                        tickLength: 16,
                        dimColor: theme.ink.opacity(0.5),
                        accentColor: .accentColor,
                        accessibilityLabel: "Moon size"
                    )
                    .padding(.vertical, 50)
                }
                .clipShape(moonSizeScrubberNotchShape)
                .padding(.trailing, (barOuterPadding / 2))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -180)
            
            BuildControlsBar(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                .glassOrSurface(glass: .tinted(ThemeColors.controlsBarTint), in: .rect(cornerRadius: panelCornerRadius))
                .clipShape(.rect(cornerRadius: panelCornerRadius))
                .padding(.horizontal, barOuterPadding)
                .padding(.bottom, barOuterPadding)
        }
        .padding(.bottom, 20)
        .ignoresSafeArea(.all, edges: .bottom)
    }

    @ViewBuilder
    private func BuildControlsBar(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        VStack(spacing: 0) {
            ZStack {
                // Always mounted — shown/hidden via `.opacity`, never inserted or
                // removed by the switch below. See `BuildScrubberAndControls`'s
                // doc comment for why that distinction matters.
                BuildScrubberAndControls(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    .padding(.bottom)
                    .opacity(viewModel.controlPresentationState == .none ? 1 : 0)
                    .allowsHitTesting(viewModel.controlPresentationState == .none)
                    .accessibilityHidden(viewModel.controlPresentationState != .none)

                switch viewModel.controlPresentationState {
                case .datePicker:
                    panelChrome(height: datePickerWheelHeight) {
                        DatePicker(
                            "Date",
                            selection: viewModel.dateBinding(dataController: dataController),
                            in: dataController.startDate...dataController.endDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsVisibility(.hidden)
                        .padding()
                    }
                case .savedItems:
                    panelChrome(height: panelHeight) {
                        SavedListView { date in
                            viewModel.selectedDate = dataController.clampedDate(date)
                            withAnimation(effectiveAnimation) {
                                viewModel.controlPresentationState = .none
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                case .settings:
                    panelChrome(height: panelHeight) {
                        SettingsPanel()
                            .scrollContentBackground(.hidden)
                    }
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

    /// Shared chrome for the three overlay panels (date picker/saved items/
    /// settings): a fixed height, a top inset that clears the close button
    /// overlaid at `.topTrailing`, the close button itself, and the panel's
    /// open/close transition — previously duplicated at each call site (and,
    /// for the top inset, duplicated inconsistently: the date picker used
    /// `.padding(.top:)` while the other two used `.safeAreaPadding(.top:)`;
    /// all three now agree on the latter).
    @ViewBuilder
    private func panelChrome<Content: View>(
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(height: height)
            .safeAreaPadding(.top, panelTopInset)
            .overlay(alignment: .topTrailing) {
                BuildCloseOverlayButton()
            }
            .transition(panelTransition)
    }

    /// Calendar/buttons capsules plus the scrub timeline. Kept mounted at all
    /// times by `BuildControlsBar` (shown/hidden via `.opacity`) rather than
    /// being one case of the presentation-state switch: switching it in and
    /// out on every date-picker/saved-items/settings open used to reset the
    /// scrub timeline's `@State` — recomputing its month-tick index and
    /// re-running its brief setup delay on every single panel close, which
    /// was visibly laggy.
    @ViewBuilder
    private func BuildScrubberAndControls(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        VStack(spacing: 0) {
            HStack {
                BuildCalendarCapsule()
                    .glassOrSurface(glass: .interactive, in: .capsule)

                Spacer()

                BuildButtonsCapsule(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                    .glassOrSurface(glass: .interactive, in: .capsule)
            }
            .padding(10)
            
            if snapshot != nil {
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
            } else {
                VStack {
                    
                }
                .frame(height: 65)
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
                withAnimation(effectiveAnimation) {
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
                    .foregroundStyle(viewModel.justSaved ? Color.accentColor : theme.ink)
            }
            .disabled(!dataController.isReady)
            .help(viewModel.justSaved ? "Saved" : "Save This View")
            .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")

            Button {
                withAnimation(effectiveAnimation) {
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
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
                .foregroundStyle(.primary)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
            
            Button {
                withAnimation(effectiveAnimation) {
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

    @ViewBuilder
    private func BuildCloseOverlayButton() -> some View {
        GlassButton(systemName: "xmark", size: 45) {
            withAnimation(effectiveAnimation) {
                viewModel.controlPresentationState = .none
            }
        }
        .help("Close")
        .accessibilityLabel("Close")
        .padding()
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
