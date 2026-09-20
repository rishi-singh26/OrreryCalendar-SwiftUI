//
//  PlanetDetailView.swift
//  Orrery
//
//  Created by Rishi Singh on 15/09/26.
//

import SwiftUI
import SwiftData

struct PlanetDetailView: View {
    @Binding var selectedDate: Date
    let theme: ThemeColors
    /// Called when the panel's close button is tapped. The caller owns dismissal (and any
    /// animation around it), since this view has no access to the presentation state that
    /// controls whether it's shown at all.
    let onClose: () -> Void

    @Environment(DataController.self) private var dataController
    @Environment(\.colorScheme) private var colorScheme

    @State private var isPlaying: Bool = true
    @State private var resetTrigger: Int = 0
    @AppStorage(AppStorageKeys.selectedPlanetIndex) private var selectedPlanetIndex: Int = 2
    @State private var tabs: [GlassSegmentedControl.Tab] = PlanetConfig.all.map { .init(title: $0.displayName) }

    /// When on, `dateBinding` below reads/writes `selectedDate` directly, so this view's
    /// scrubber and the caller's date selection stay in sync. When off, it reads/writes
    /// `localDate` instead, so scrubbing here never changes the caller's date (and vice versa).
    @AppStorage(AppStorageKeys.syncPlanetDetailDate) private var syncPlanetDetailDate = true
    /// Backing date used when `syncPlanetDetailDate` is off. Seeded from `selectedDate` at
    /// init, so this view starts in step with the caller's date every time it's shown —
    /// since it's constructed fresh each time it's presented, that init also re-seeds this
    /// on every reopen.
    @State private var localDate: Date

    init(selectedDate: Binding<Date>, theme: ThemeColors, onClose: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.theme = theme
        self.onClose = onClose
        self._localDate = State(initialValue: selectedDate.wrappedValue)
    }

    private var selectedPlanet: PlanetConfig {
        PlanetConfig.all[max(min(selectedPlanetIndex, PlanetConfig.all.count - 1), 0)]
    }

    private var planetName: String {
        selectedPlanet.displayName
    }

    /// The date this view displays — `selectedDate` when synced, `localDate` otherwise.
    private var effectiveDate: Date {
        syncPlanetDetailDate ? selectedDate : localDate
    }

    /// The binding handed to the scrub timeline below.
    private var dateBinding: Binding<Date> {
        guard syncPlanetDetailDate else {
            return Binding(
                get: { localDate },
                set: { localDate = dataController.clampedDate($0) }
            )
        }
        return $selectedDate
    }

    private var measurements: [PlanetMeasurement] {
        PlanetMeasurementsProvider.measurements(for: selectedPlanet, on: effectiveDate)
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height
            let layout: AnyLayout = isWide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            
            layout {
                USDZRenderView(name: planetName, isPlaying: isPlaying, resetTrigger: resetTrigger)
                    .frame(height: isWide ? nil : 400)
                
                Divider()
                    .padding(.horizontal, isWide ? nil : 10)
                
                VStack {
                    
                    BuildList()
                        .safeAreaPadding(.top, isWide ? 60 : nil)
                    
                    GlassSegmentedControl(
                        config: .init(tint: .accentColor),
                        selection: $selectedPlanetIndex,
                        tabs: $tabs
                    )
                    .padding(.vertical, 5)
                    
                    ScrubTimelineNoAnimationView(
                        selectedDate: dateBinding,
                        minDate: dataController.startDate,
                        maxDate: dataController.endDate,
                        theme: theme
                    )
                    .padding(.bottom, 5)
                }
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        colorScheme == .dark
                        ? .orange.mix(with: .black, by: 0.4).opacity(0.4)
                        : .orange.mix(with: .gray, by: 0.3).opacity(0.6),
                        .clear
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
            }
            .overlay(alignment: .topLeading) {
                let font: Font = DeviceType.isIphone ? .subheadline : .title
                HStack {
                    SelectedDateTitleText(date: effectiveDate, font: font.bold().monospaced())
                    
                    Spacer()
                    
                    GlassButton(systemName: "arrow.counterclockwise", size: 45) {
                        resetTrigger += 1
                    }
                    
                    GlassButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: 45) {
                        isPlaying.toggle()
                    }
                    
                    GlassButton(systemName: "xmark", size: 45) {
                        onClose()
                    }
                    .help("Close")
                    .accessibilityLabel("Close")
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func BuildList() -> some View {
        let font: Font = DeviceType.isMac ? .body : .caption
        List(measurements) { measurement in
            HStack {
                Text(measurement.label)
                    .font(font.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(measurement.value)
                    .font(font.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, DeviceType.isMac ? 5 : 0)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    ContentView()
        .environment(DataController(modelContainer: try! ModelContainer(
            for: PlanetDataStore.self, SavedSnapshot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
}
