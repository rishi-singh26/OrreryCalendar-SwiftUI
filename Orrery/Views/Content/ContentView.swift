//
//  ContentView.swift
//  Orrery
//
//  Root composition (spec §5–§7): the orrery chart, Moon phase row, scrub timeline, and
//  toolbar (date picker, save, saved list, share, settings). Adapts chrome per platform
//  where noted; the core layout is shared.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        #if os (iOS)
        if DeviceType.isIphone {
            SmallScreenView()
        } else {
            LargeScreenView()
        }
        #else
        LargeScreenView()
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
