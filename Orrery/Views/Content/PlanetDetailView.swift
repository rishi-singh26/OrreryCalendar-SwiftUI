//
//  PlanetDetailView.swift
//  Orrery
//
//  Created by Rishi Singh on 15/09/26.
//

import SwiftUI
import SwiftData

struct PlanetDetailView: View {
    @State private var isPlaying: Bool = true
    @State private var selectedPlanetIndex: Int = 2
    @State private var tabs: [GlassSegmentedControl.Tab] = [
        .init(title: "Mercury"),
        .init(title: "Venus"),
        .init(title: "Earth"),
        .init(title: "Mars"),
        .init(title: "Jupiter"),
        .init(title: "Saturn"),
        .init(title: "Uranus"),
        .init(title: "Neptune")
    ]

    private var planetName: String {
        tabs[selectedPlanetIndex].title
    }

    var body: some View {
        VStack(spacing: 0) {
            USDZRenderView(name: planetName, isPlaying: isPlaying)
            
            HStack {
                Text(planetName)
                    .font(.title.monospaced())
                    .fontWeight(.semibold)
                
                Spacer()
                
                GlassButton(
                    systemName: isPlaying ? "pause.fill" : "play.fill",
                    size: 45
                ) {
                    isPlaying.toggle()
                }
            }
            .padding([.horizontal, .bottom])
            
            List {
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                HStack {
                    Text("Distance from Sun")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("150 million kilometers")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .listStyle(.plain)
            
            GlassSegmentedControl(
                config: .init(tint: .accentColor),
                selection: $selectedPlanetIndex,
                tabs: $tabs
            )
            .padding(.vertical, 5)
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
