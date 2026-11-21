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
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.make()
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
                .inAppNotificationOverlay()
        }
        .modelContainer(modelContainer)
        #if os (macOS)
        .windowStyle(.hiddenTitleBar)
        #endif

        #if os(macOS)
        Settings {
            SettingsPanel()
                .environment(dataController)
                .inAppNotificationOverlay()
        }
        .defaultSize(width: 400, height: 700)
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        #endif
    }
}
