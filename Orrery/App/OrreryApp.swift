//
//  OrreryApp.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI
import SwiftData

@main
struct OrreryApp: App {
    let modelContainer: ModelContainer
    @State private var dataController: DataController

    init() {
        let schema = Schema([PlanetDataStore.self, SavedSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.modelContainer = container
        _dataController = State(initialValue: DataController(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataController)
        }
        .modelContainer(modelContainer)
        #if os (macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
