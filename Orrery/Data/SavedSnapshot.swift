//
//  SavedSnapshot.swift
//  Orrery
//
//  A user-saved date, freezing the exact planet values and Moon phase at save time so
//  it works fully offline afterward, independent of the cached range (spec §7).
//
//  Note: avoids a `Dictionary`/nested-struct property directly on the `@Model` type for
//  widest SwiftData compatibility — structured per-planet data is JSON-encoded into a
//  plain `Data` column instead, per spec's explicit guidance.
//

import Foundation
import SwiftData

@Model
final class SavedSnapshot {
    var id: UUID = UUID()
    var date: Date // UTC midnight of the saved day
    var savedAt: Date = Date()
    var moonPhaseDeg: Double = 0
    var planetValuesData: Data = Data() // JSON-encoded [PlanetValue]

    /// Decoded lazily from `planetValuesData` and cached here so repeated
    /// `planetValues`/`daySnapshot` access (e.g. re-rendering a row's context menu or
    /// share preview) doesn't re-run `JSONDecoder` every time. `@Transient` excludes it
    /// from the persisted schema — it's purely a derived in-memory cache, rebuilt from
    /// `planetValuesData` on first access after this object is fetched from the store.
    @Transient private var cachedPlanetValues: [PlanetValue]?

    init(date: Date, moonPhaseDeg: Double, planets: [PlanetValue]) {
        self.id = UUID()
        self.date = date
        self.savedAt = Date()
        self.moonPhaseDeg = moonPhaseDeg
        self.planetValuesData = (try? JSONEncoder().encode(planets)) ?? Data()
        self.cachedPlanetValues = planets
    }

    var planetValues: [PlanetValue] {
        if let cachedPlanetValues { return cachedPlanetValues }
        let decoded = (try? JSONDecoder().decode([PlanetValue].self, from: planetValuesData)) ?? []
        cachedPlanetValues = decoded
        return decoded
    }

    var daySnapshot: DaySnapshot {
        DaySnapshot(date: date, planets: planetValues, moonPhaseDeg: moonPhaseDeg)
    }
}
