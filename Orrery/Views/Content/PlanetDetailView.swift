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

    @Environment(DataController.self) private var dataController

    @State private var isPlaying: Bool = true
    @State private var resetTrigger: Int = 0
    @AppStorage("selectedPlanetIndex") private var selectedPlanetIndex: Int = 2
    @State private var tabs: [GlassSegmentedControl.Tab] = PlanetConfig.all.map { .init(title: $0.displayName) }

    private var selectedPlanet: PlanetConfig {
        PlanetConfig.all[max(min(selectedPlanetIndex, PlanetConfig.all.count - 1), 0)]
    }

    private var planetName: String {
        selectedPlanet.displayName
    }

    private var measurements: [PlanetMeasurement] {
        PlanetMeasurementsProvider.measurements(for: selectedPlanet, on: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            USDZRenderView(name: planetName, isPlaying: isPlaying, resetTrigger: resetTrigger)

            BuildHeader()
            
            BuildList()
            
            GlassSegmentedControl(
                config: .init(tint: .accentColor),
                selection: $selectedPlanetIndex,
                tabs: $tabs
            )
            .padding(.vertical, 5)

            ScrubTimelineNoAnimationView(
                selectedDate: $selectedDate,
                minDate: dataController.startDate,
                maxDate: dataController.endDate,
                theme: theme
            )
            .padding(.bottom, 5)
        }
    }
    
    @ViewBuilder
    private func BuildHeader() -> some View {
        HStack {
            Text(planetName)
                .font(.title.monospaced())
                .fontWeight(.semibold)

            Spacer()

            GlassButton(systemName: "arrow.counterclockwise", size: 45) {
                resetTrigger += 1
            }

            GlassButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: 45) {
                isPlaying.toggle()
            }
        }
        .padding([.horizontal, .bottom])
    }
    
    @ViewBuilder
    private func BuildList() -> some View {
        List(measurements) { measurement in
            HStack {
                Text(measurement.label)
                    .font(.caption.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(measurement.value)
                    .font(.caption.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(DataController(modelContainer: try! ModelContainer(
            for: PlanetDataStore.self, SavedSnapshot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
}
