//
//  ModelContainerFactory.swift
//  Orrery
//
//  Builds the app's SwiftData container as two separate stores:
//  - `PlanetCache` (`PlanetDataStore`): a large, deterministic, per-device cache. Local
//    only — syncing it would waste iCloud quota and make devices fight over the single
//    delete-and-reinsert record.
//  - `SavedSnapshots` (`SavedSnapshot`): the user's saved dates, mirrored to their
//    private CloudKit database so they sync across the user's devices.
//
//  Previews/tests pass `inMemory: true`, which also disables CloudKit; otherwise the
//  iCloud entitlement would make SwiftData try to mirror every in-memory model too.
//

import Foundation
import SwiftData

enum ModelContainerFactory {
    /// Must match the container in `Orrery.entitlements`.
    static let cloudContainerID = "iCloud.in.rishisingh.Orrery"

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let cache = ModelConfiguration(
            "PlanetCache",
            schema: Schema([PlanetDataStore.self]),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        let saved = ModelConfiguration(
            "SavedSnapshots",
            schema: Schema([SavedSnapshot.self]),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(cloudContainerID)
        )
        return try ModelContainer(
            for: Schema([PlanetDataStore.self, SavedSnapshot.self]),
            configurations: [cache, saved]
        )
    }
}
