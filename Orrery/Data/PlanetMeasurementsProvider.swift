//
//  PlanetMeasurementsProvider.swift
//  Orrery
//

import Foundation
import AstronomyEngineSwift

/// One labeled row in `PlanetDetailView`'s measurements list.
struct PlanetMeasurement: Identifiable {
    let id: String
    let label: String
    let value: String
}

/// Computes live, per-date measurements for a single planet — distances to every
/// other body, orbital period, and apparent magnitude. Unlike `PlanetEngineClient`
/// (which precomputes/caches every planet for every day in a wide range), this only
/// ever computes for one planet on one date at a time, so it stays synchronous and
/// uncached.
enum PlanetMeasurementsProvider {
    private static let kmPerAU = 149_597_870.7

    /// All rows for `planet` on `date`: distance from the Sun and every other planet
    /// (Sun first, then Mercury→Neptune, skipping `planet` itself), then orbital
    /// period, then apparent magnitude. Rows the engine can't compute for this body
    /// (e.g. magnitude when `planet` is Earth) are simply omitted.
    static func measurements(for planet: PlanetConfig, on date: Date) -> [PlanetMeasurement] {
        guard let selectedBody = CelestialBody(rawValue: planet.name) else { return [] }
        let time = AstronomyEngine.time(for: date)

        var rows: [PlanetMeasurement] = []

        let referenceBodies: [CelestialBody] = [.sun] + orderedPlanets
        for body in referenceBodies where body != selectedBody {
            guard let au = try? AstronomyEngine.distance(from: body, to: selectedBody, time: time) else { continue }
            rows.append(PlanetMeasurement(
                id: "distance-\(body.rawValue)",
                label: "Distance from \(displayName(for: body))",
                value: formatDistance(au: au)
            ))
        }

        rows.append(PlanetMeasurement(
            id: "orbital-period",
            label: "Orbital Period",
            value: formatOrbitalPeriod(days: AstronomyEngine.orbitalPeriodDays(body: selectedBody))
        ))

        if let illumination = try? AstronomyEngine.illumination(body: selectedBody, time: time) {
            rows.append(PlanetMeasurement(
                id: "apparent-magnitude",
                label: "Apparent Magnitude",
                value: String(format: "%.2f", illumination.magnitude)
            ))
        }

        return rows
    }

    private static func displayName(for body: CelestialBody) -> String {
        body == .sun ? "Sun" : (PlanetConfig.config(named: body.rawValue)?.displayName ?? body.rawValue.capitalized)
    }

    private static func formatDistance(au: Double) -> String {
        let km = au * kmPerAU
        switch km {
        case ..<1_000_000: return String(format: "%.0f thousand km", km / 1_000)
        case ..<1_000_000_000: return String(format: "%.2f million km", km / 1_000_000)
        default: return String(format: "%.2f billion km", km / 1_000_000_000)
        }
    }

    private static func formatOrbitalPeriod(days: Double) -> String {
        String(format: "%.1f days (%.2f years)", days, days / 365.25)
    }
}
