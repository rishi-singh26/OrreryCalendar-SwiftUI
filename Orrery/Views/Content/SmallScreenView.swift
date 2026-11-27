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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    @AppStorage(AppStorageKeys.autoPlayEnabled) private var autoPlayEnabled = true
    @AppStorage(AppStorageKeys.showMoonSizeScrubber) private var showMoonSizeScrubber = true
    @AppStorage(AppStorageKeys.autoPlayRate) private var autoPlayRate: AutoPlayRate = AutoPlayRate.defaultRate
    
    @State private var viewModel = ContentViewModel()
    
    /// Persisted, normalized (`0...1`) position of the leading-edge Moon-size
    /// scrubber. `0.5` (its default) maps to `1.0` via `viewModel.moonSizeMultiplier`,
    /// reproducing `MoonPhaseRow`'s normal size until the user drags it. Kept here
    /// (rather than in `ContentViewModel`) since `@AppStorage` only integrates with
    /// SwiftUI's view-update machinery when it's declared directly on a `View` —
    /// same reason every other persisted display setting (`showOrbits` etc.) lives
    /// in the view, not the view model.
    @AppStorage(AppStorageKeys.moonSizeScrub) private var moonSizeScrub: Double = 0.5
    
    /// The size multiplier `MoonPhaseRow` reads — the actual `moonSizeScrub` →
    /// multiplier mapping is pure business logic, so it lives on `viewModel`.
    private var moonSizeMultiplier: CGFloat {
        viewModel.moonSizeMultiplier(forScrub: moonSizeScrub)
    }
    
    private let backgroundCornerRadius: CGFloat = 40
    private let panelCornerRadius: CGFloat = 37
    private let barOuterPadding: CGFloat = 6
    private let viewBottonPadding: CGFloat = 20
    
    /// `animation`, softened when Reduce Motion is on — used at every call
    /// site that changes `viewModel.controlPresentationState`.
    private var effectiveAnimation: Animation {
        viewModel.effectiveAnimation(reduceMotion: reduceMotion)
    }
    
    var body: some View {
        // Looked up once per body evaluation and handed down to the main content, rather
        // than each child independently calling `dataController.snapshot(for:)` (a
        // `UTCDay` calendar-based lookup).
        let snapshot = dataController.snapshot(for: viewModel.selectedDate)
        ThemeReader { theme, colorScheme in
            ZStack {
                BackgroundView()
                    .cornerRadius(backgroundCornerRadius)
                    .padding(.horizontal, (barOuterPadding / 2))
                    .padding(.bottom, viewBottonPadding)
                    .ignoresSafeArea(.all, edges: .bottom)
                
                MainContentBuilder(snapshot: snapshot, theme: theme, colorScheme: colorScheme)
            }
        }
        .contentLifecycle(viewModel: viewModel, observing: .changesOnly)
        .extendRangeToast(viewModel: viewModel) {
            withAnimation(effectiveAnimation) {
                viewModel.controlPresentationState = .settings
            }
        }
    }
    
    @ViewBuilder
    private func MainContentBuilder(snapshot: DaySnapshot?, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                SmallScreenHeader(viewModel: viewModel)
                
                // Always mounted — `OrreryView` shows its own loading pose (planets
                // lined up left of their orbits) while `snapshot` is nil, then eases
                // into place once it arrives, rather than the chart not appearing
                // at all until data is ready.
                OrreryView(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, theme: theme,
                    aspectRatio: 1, dateChangeAnimationTrigger: viewModel.dateChangeAnimationTrigger
                )
                
                if let snapshot {
                    MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, theme: theme, sizeMultiplier: moonSizeMultiplier)
                }
                Spacer(minLength: 0)
            }
            .onTapGesture {
                withAnimation(effectiveAnimation) {
                    viewModel.controlPresentationState = .none
                }
            }
            
            // Drives `moonSizeMultiplier` (via `moonSizeScrub`), which `MoonPhaseRow` above
            // animates into on change.
            MoonSizeScrubberNotch(scrub: $moonSizeScrub, theme: theme, isPresented: showMoonSizeScrubber)
                .padding(.leading, (barOuterPadding / 2))
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -180)
            
            // Drawn before the Auto Play button below so the button stays on top (and
            // tappable) where the two overlap. Only shown while playing.
            AutoPlaySpeedNotch(rate: $autoPlayRate, isPresented: autoPlayEnabled && viewModel.autoPlay.isPlaying)
                .padding(.trailing, (barOuterPadding / 2))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -180)
            
            if autoPlayEnabled {
                let isPlaying = viewModel.autoPlay.isPlaying
                GlassButton(circular: true, size: 45, useInteractiveGlass: true) {
                    withAnimation(effectiveAnimation) {
                        viewModel.toggleAutoPlay(dataController: dataController)
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(!dataController.isReady)
                .help(isPlaying ? "Pause Auto Play" : "Start Auto Play")
                .accessibilityLabel("Auto play")
                .accessibilityValue(isPlaying ? "Playing" : "Paused")
                .padding(.trailing, barOuterPadding)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -160)
            }
            
            SmallScreenControlsBar(viewModel: viewModel, snapshot: snapshot, theme: theme, colorScheme: colorScheme)
                .glassOrSurface(glass: .tinted(ThemeColors.controlsBarTint), in: .rect(cornerRadius: panelCornerRadius))
                .clipShape(.rect(cornerRadius: panelCornerRadius))
                .padding(.horizontal, barOuterPadding)
                .padding(.vertical, barOuterPadding / 2)
        }
        .padding(.bottom, viewBottonPadding)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    ContentView()
        .environment(DataController(modelContainer: try! ModelContainerFactory.make(inMemory: true)))
}
#endif
