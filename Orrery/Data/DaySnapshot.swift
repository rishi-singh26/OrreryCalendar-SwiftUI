//
//  DaySnapshot.swift
//  Orrery
//

import Foundation

/// One planet's position on a given day. `name` matches `PlanetEngineClient.bodyNames`.
struct PlanetValue: Codable, Equatable, Sendable {
    var name: String
    var distanceAU: Double
    var angleDeg: Double
}

/// Everything the UI needs to render one day: the Sun/planets chart and both Moon
/// phase discs. Decoded from `PlanetDataStore`'s packed blob, or reconstructed from a
/// frozen `SavedSnapshot`.
struct DaySnapshot: Equatable, Sendable {
    var date: Date // UTC midnight
    var planets: [PlanetValue] // fixed order, matches PlanetEngineClient.bodyNames
    var moonPhaseDeg: Double

    /// Illuminated fraction, 0 (new) ... 1 (full), per spec §2: k = (1 - cos(phase)) / 2.
    var illuminatedFraction: Double {
        (1 - cos(moonPhaseDeg * .pi / 180)) / 2
    }

    func planetValue(named name: String) -> PlanetValue? {
        planets.first { $0.name == name }
    }
}
