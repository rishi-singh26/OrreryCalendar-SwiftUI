//
//  DataStoreIO.swift
//  Orrery
//
//  All `PlanetDataStore` reads/writes happen through this background actor, on its own
//  `ModelContext` — never the main-thread context the UI reads through (spec's explicit
//  SwiftData-threading requirement). Only plain Sendable value types cross the actor
//  boundary; the `@Model` instances themselves never leave this actor.
//

import Foundation
import SwiftData

/// A snapshot of `PlanetDataStore`'s fields as a plain Sendable value, safe to hand to
/// the main-actor `DataController`.
struct StoreSnapshot: Sendable {
    var startDate: Date
    var endDate: Date
    var dayCount: Int
    var bodies: [String]
    var bytesPerDay: Int
    var distanceScale: Double
    var angleScale: Double
    var moonPhaseScale: Double
    var packedData: Data
    var formatVersion: Int
}

actor DataStoreIO {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Loads the single cached `PlanetDataStore` record, if one exists and its
    /// `formatVersion` matches the current layout. A version mismatch is treated the
    /// same as "no store" — the caller recomputes from scratch rather than misreading
    /// old bytes under a new interpretation.
    func loadStore() throws -> StoreSnapshot? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlanetDataStore>()
        let records = try context.fetch(descriptor)
        guard let record = records.first else { return nil }

        guard record.formatVersion == PlanetDataStore.currentFormatVersion else {
            return nil
        }

        return StoreSnapshot(
            startDate: record.startDate,
            endDate: record.endDate,
            dayCount: record.dayCount,
            bodies: record.bodies,
            bytesPerDay: record.bytesPerDay,
            distanceScale: record.distanceScale,
            angleScale: record.angleScale,
            moonPhaseScale: record.moonPhaseScale,
            packedData: record.packedData,
            formatVersion: record.formatVersion
        )
    }

    /// Atomically replaces the cached store: the new blob is fully computed in memory
    /// by the caller before this is invoked, and this method deletes any existing
    /// record(s) and inserts the new one within a single `save()` call. If `save()`
    /// throws (e.g. disk full), nothing was persisted — the previously-committed record
    /// is untouched on disk, so a crash or this error never leaves a truncated/corrupt
    /// blob behind.
    func replaceStore(startDate: Date, endDate: Date, dayCount: Int, packedData: Data) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<PlanetDataStore>()
        let existing = try context.fetch(descriptor)
        for record in existing {
            context.delete(record)
        }
        let store = PlanetDataStore(
            startDate: startDate,
            endDate: endDate,
            dayCount: dayCount,
            packedData: packedData
        )
        context.insert(store)
        try context.save()
    }
}
