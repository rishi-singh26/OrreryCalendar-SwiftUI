//
//  PlanetDetailView.swift
//  Orrery
//
//  Created by Rishi Singh on 15/09/26.
//

import SwiftUI
import SwiftData

struct PlanetDetailView: View {
    let selectedDate: Date

    @State private var isPlaying: Bool = true
    @State private var resetTrigger: Int = 0
    @AppStorage("selectedPlanetIndex") private var selectedPlanetIndex: Int = 2
    @State private var tabs: [GlassSegmentedControl.Tab] = PlanetConfig.all.map { .init(title: $0.displayName) }

    private var selectedPlanet: PlanetConfig {
        PlanetConfig.all[selectedPlanetIndex]
    }

    private var planetName: String {
        selectedPlanet.displayName
    }

    private var measurements: [PlanetMeasurement] {
        PlanetMeasurementsProvider.measurements(for: selectedPlanet, on: selectedDate)
    }
    
    /// The plain formatted string, for callers that need text rather than a `View` —
    /// e.g. `PolaroidShareButton`'s `SharePreview` caption.
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
    
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

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
        }
    }
    
    @ViewBuilder
    private func BuildHeader() -> some View {
        HStack {
            HStack(alignment: .bottom) {
                Text(planetName)
                    .font(.title.monospaced())
                    .fontWeight(.semibold)
                Text("On \(Self.string(from: selectedDate))")
                    .font(.caption.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)
            }

            Spacer()

            GlassButton(
                systemName: "arrow.counterclockwise",
                size: 45
            ) {
                resetTrigger += 1
            }

            GlassButton(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                size: 45
            ) {
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
