//
//  ModelContainerFactory.swift
//  Orrery
//
//  Builds the app's SwiftData container as two separate stores:
//  - `PlanetCache` (`PlanetDataStore`): a large, deterministic, per-device cache. Local
//    only — syncing it would waste iCloud quota and make devices fight over the single
//    delete-and-reinsert record.
//  - `SavedSnapshots` (`SavedSnapshot`): the user's saved dates, mirrored to their
//    private CloudKit database so they sync across the user's devices. Uses the app's
//    (single) iCloud container from `Orrery.entitlements`.
//
//  If the CloudKit-backed container can't be built, `make` logs the error and falls back to
//  the same stores without sync, so the app still launches and saves locally.
//
//  Previews pass `inMemory: true`, which also disables CloudKit; otherwise the iCloud
//  entitlement would make SwiftData try to mirror every in-memory model too.
//

import Foundation
import SwiftData
import OSLog

enum ModelContainerFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Orrery", category: "ModelContainer")
    
    /// Builds the container with CloudKit sync for saved dates. If that fails (e.g. the
    /// CloudKit schema is rejected), falls back to the same stores without sync so the app
    /// still launches and saving keeps working locally; only a failure of the local-only
    /// setup is thrown.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try build(inMemory: true, syncSavedSnapshots: false)
        }
        do {
            return try build(inMemory: false, syncSavedSnapshots: true)
        } catch {
            logger.error("CloudKit-backed container failed, falling back to local-only: \(error)")
            return try build(inMemory: false, syncSavedSnapshots: false)
        }
    }
    
    private static func build(inMemory: Bool, syncSavedSnapshots: Bool) throws -> ModelContainer {
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
            cloudKitDatabase: syncSavedSnapshots ? .automatic : .none
        )
        return try ModelContainer(
            for: Schema([PlanetDataStore.self, SavedSnapshot.self]),
            configurations: [cache, saved]
        )
    }
}
