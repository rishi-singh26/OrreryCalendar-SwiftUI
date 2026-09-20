//
//  PlanetMeasurementsProviderTests.swift
//  OrreryTests
//

import Testing
import Foundation
@testable import AstronomyEngineSwift
@testable import Orrery

/// Coverage for `PlanetMeasurementsProvider` (Orrery/Data/PlanetMeasurementsProvider.swift):
/// row structure/ordering, label/value formatting, and — the case that prompted this file —
/// whether Earth's "Distance from Sun" actually behaves the way real orbital mechanics says
/// it should across the Nov/Dec/Jan window, rather than the (incorrect) intuition that a
/// colder Northern-Hemisphere season means Earth is farther from the Sun. Earth's perihelion
/// (closest approach) falls in early January and its aphelion (farthest) in early July —
/// seasons are driven by axial tilt, not solar distance. `referenceValues_2026_01_04` in
/// OrreryTests.swift already pins Earth at 0.9833 AU on 2026-01-04, consistent with that.
struct PlanetMeasurementsProviderTests {

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    /// Converts a formatted distance value (e.g. "147.14 million km", "4.47 billion km",
    /// "389 thousand km") back into a plain km `Double`, so tests can compare against
    /// values computed directly from `AstronomyEngine` without duplicating
    /// `formatDistance`'s exact rounding. Also returns the max rounding error that bucket's
    /// fixed decimal precision can introduce (e.g. "%.2f billion km" only resolves to
    /// ±0.005 billion km == ±5,000,000 km), so callers can allow for it.
    private static func kmValue(fromFormatted value: String) -> (km: Double, roundingTolerance: Double) {
        let numberPart = value.split(separator: " ").first.flatMap { Double($0) } ?? .nan
        if value.contains("billion") { return (numberPart * 1_000_000_000, 0.005 * 1_000_000_000) }
        if value.contains("million") { return (numberPart * 1_000_000, 0.005 * 1_000_000) }
        if value.contains("thousand") { return (numberPart * 1_000, 0.5 * 1_000) }
        return (numberPart, 0.5)
    }

    private static func distanceRow(_ rows: [PlanetMeasurement], bodyId: String) -> PlanetMeasurement? {
        rows.first { $0.id == "distance-\(bodyId)" }
    }

    // MARK: - Row structure

    /// Earth's row set: orbital period, a distance row for every other body (Sun + the 7
    /// other planets) with no self-distance row, and — since the underlying engine rejects
    /// "illumination as seen from Earth" of Earth itself — no apparent-magnitude row either.
    @Test func earth_rowStructure_excludesSelfDistanceAndMagnitude() throws {
        let earth = try #require(PlanetConfig.config(named: "earth"))
        let rows = PlanetMeasurementsProvider.measurements(for: earth, on: Self.utcDate(year: 2026, month: 1, day: 4))

        #expect(rows.first?.id == "orbital-period")
        #expect(Self.distanceRow(rows, bodyId: "earth") == nil, "should not list Earth's distance from itself")
        #expect(Self.distanceRow(rows, bodyId: "sun") != nil)
        for other in ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"] {
            #expect(Self.distanceRow(rows, bodyId: other) != nil, "missing distance row for \(other)")
        }
        #expect(!rows.contains { $0.id == "apparent-magnitude" }, "Earth has no apparent magnitude (undefined as seen from itself)")
        #expect(rows.count == 9, "orbital period + 8 distance rows (Sun + 7 other planets), no magnitude")
    }

    /// Every non-Earth planet gets the same shape as Earth, plus a trailing apparent
    /// magnitude row, since illumination is only undefined for Earth.
    @Test func nonEarthPlanets_rowStructure_includesMagnitudeAndExcludesSelfDistance() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)
        for planet in PlanetConfig.all where planet.name != "earth" {
            let rows = PlanetMeasurementsProvider.measurements(for: planet, on: date)
            #expect(rows.first?.id == "orbital-period", "\(planet.name): first row should be orbital period")
            #expect(Self.distanceRow(rows, bodyId: planet.name) == nil, "\(planet.name): should not list its own distance")
            #expect(rows.last?.id == "apparent-magnitude", "\(planet.name): last row should be apparent magnitude")
            #expect(rows.count == 10, "\(planet.name): orbital period + 8 distance rows + magnitude")
        }
    }

    /// Distance rows must stay in Sun-then-Mercury→Neptune order with the selected planet
    /// skipped in place (not shifted or reordered around the gap).
    @Test func distanceRows_orderedSunThenOutwardSkippingSelf() throws {
        let mars = try #require(PlanetConfig.config(named: "mars"))
        let rows = PlanetMeasurementsProvider.measurements(for: mars, on: Self.utcDate(year: 2026, month: 1, day: 4))
        let distanceIds = rows.filter { $0.id.hasPrefix("distance-") }.map { $0.id }
        #expect(distanceIds == [
            "distance-sun", "distance-mercury", "distance-venus",
            "distance-earth", "distance-jupiter", "distance-saturn",
            "distance-uranus", "distance-neptune",
        ])
    }

    /// Labels must read "Distance from <Sun/display name>", using the Sun's special-cased
    /// label and each planet's `PlanetConfig.displayName` (not its lowercase engine name).
    @Test func distanceRowLabels_useDisplayNames() throws {
        let venus = try #require(PlanetConfig.config(named: "venus"))
        let rows = PlanetMeasurementsProvider.measurements(for: venus, on: Self.utcDate(year: 2026, month: 1, day: 4))
        #expect(Self.distanceRow(rows, bodyId: "sun")?.label == "Distance from Sun")
        #expect(Self.distanceRow(rows, bodyId: "mercury")?.label == "Distance from Mercury")
        #expect(Self.distanceRow(rows, bodyId: "earth")?.label == "Distance from Earth")
        #expect(Self.distanceRow(rows, bodyId: "neptune")?.label == "Distance from Neptune")
    }

    /// An unrecognized planet name (one with no matching `CelestialBody` case) must yield
    /// an empty result rather than crashing or fabricating rows.
    @Test func unknownPlanetName_returnsEmptyRows() throws {
        let bogus = PlanetConfig(name: "pluto", displayName: "Pluto", referenceSize: 1)
        let rows = PlanetMeasurementsProvider.measurements(for: bogus, on: Self.utcDate(year: 2026, month: 1, day: 4))
        #expect(rows.isEmpty)
    }

    // MARK: - Value correctness against the engine

    /// Every "Distance from X" row's displayed km value must match a direct
    /// `AstronomyEngine.distance` computation for the same pair/date, across both the
    /// million-km and billion-km formatting buckets that real planet pairs actually land in
    /// (Mercury–Venus is the closest pair at ~61M km; Sun–Neptune the farthest at ~4.47B km).
    @Test func distanceValues_matchDirectEngineComputation() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)
        let time = AstronomyEngine.time(for: date)
        let kmPerAU = 149_597_870.7

        for planet in PlanetConfig.all {
            guard let selectedBody = CelestialBody(rawValue: planet.name) else { continue }
            let rows = PlanetMeasurementsProvider.measurements(for: planet, on: date)
            for body in [CelestialBody.sun] + orderedPlanets where body != selectedBody {
                guard let row = Self.distanceRow(rows, bodyId: body.rawValue) else {
                    Issue.record("\(planet.name): missing distance row for \(body.rawValue)")
                    continue
                }
                let expectedAU = try AstronomyEngine.distance(from: body, to: selectedBody, time: time)
                let expectedKm = expectedAU * kmPerAU
                let (actualKm, roundingTolerance) = Self.kmValue(fromFormatted: row.value)
                #expect(abs(actualKm - expectedKm) <= roundingTolerance, "\(planet.name)/\(body.rawValue): got \(row.value) (~\(actualKm) km), expected ~\(expectedKm) km")
            }
        }
    }

    /// `distance(from: .sun, to: body)` (what every "Distance from Sun" row uses) must agree
    /// with the engine's own dedicated heliocentric-distance function — if these ever
    /// diverged, the Sun row would be quietly wrong for every planet.
    @Test func distanceFromSun_agreesWithHelioDistance() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)
        for body in orderedPlanets {
            let viaVectors = try AstronomyEngine.distance(from: .sun, to: body, date: date)
            let viaHelio = try AstronomyEngine.helioDistance(body: body, date: date)
            #expect(abs(viaVectors - viaHelio) < 1e-6, "\(body): distance-from-sun (\(viaVectors)) should match helioDistance (\(viaHelio))")
        }
    }

    /// Orbital period row must reflect `AstronomyEngine.orbitalPeriodDays` formatted as
    /// "<days> days (<years> years)", for every planet.
    @Test func orbitalPeriodRow_matchesEngineValue() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)
        for planet in PlanetConfig.all {
            guard let selectedBody = CelestialBody(rawValue: planet.name) else { continue }
            let rows = PlanetMeasurementsProvider.measurements(for: planet, on: date)
            let days = AstronomyEngine.orbitalPeriodDays(body: selectedBody)
            let expected = String(format: "%.1f days (%.2f years)", days, days / 365.25)
            #expect(rows.first { $0.id == "orbital-period" }?.value == expected, "\(planet.name) orbital period mismatch")
        }
    }

    /// Apparent magnitude row (non-Earth planets) must match `AstronomyEngine.illumination`
    /// formatted to 2 decimal places.
    @Test func apparentMagnitudeRow_matchesEngineValue() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)
        for planet in PlanetConfig.all where planet.name != "earth" {
            guard let selectedBody = CelestialBody(rawValue: planet.name) else { continue }
            let rows = PlanetMeasurementsProvider.measurements(for: planet, on: date)
            let expectedMagnitude = try AstronomyEngine.illumination(body: selectedBody, date: date).magnitude
            let expected = String(format: "%.2f", expectedMagnitude)
            #expect(rows.first { $0.id == "apparent-magnitude" }?.value == expected, "\(planet.name) magnitude mismatch")
        }
    }

    // MARK: - Seasonal distance trend (the reported concern)

    /// Earth's Sun-distance must trace real orbital mechanics: it keeps *decreasing*
    /// through Northern-Hemisphere autumn/winter into a January perihelion, then
    /// *increasing* through spring into a July aphelion, then decreasing again back toward
    /// the next winter — the opposite of the intuition that a colder season should mean a
    /// larger Sun distance. (Seasons come from axial tilt, not orbital distance.) This
    /// pins the actual minimum to early January and the actual maximum to early July, so a
    /// regression that flipped or scrambled the distance computation would be caught here.
    @Test func earthDistanceFromSun_perihelionInJanuary_aphelionInJuly() throws {
        let earth = try #require(PlanetConfig.config(named: "earth"))

        func sunDistanceKm(_ year: Int, _ month: Int, _ day: Int) -> Double {
            let date = Self.utcDate(year: year, month: month, day: day)
            let rows = PlanetMeasurementsProvider.measurements(for: earth, on: date)
            let value = Self.distanceRow(rows, bodyId: "sun")?.value ?? ""
            return Self.kmValue(fromFormatted: value).km
        }

        let samples: [(label: String, km: Double)] = [
            ("2025-11-01", sunDistanceKm(2025, 11, 1)),
            ("2025-12-01", sunDistanceKm(2025, 12, 1)),
            ("2026-01-04 (perihelion)", sunDistanceKm(2026, 1, 4)),
            ("2026-02-01", sunDistanceKm(2026, 2, 1)),
            ("2026-04-01", sunDistanceKm(2026, 4, 1)),
            ("2026-07-05 (aphelion)", sunDistanceKm(2026, 7, 5)),
            ("2026-09-01", sunDistanceKm(2026, 9, 1)),
        ]

        // Decreasing into perihelion.
        #expect(samples[0].km > samples[1].km, "Nov -> Dec should move closer to the Sun, not farther")
        #expect(samples[1].km > samples[2].km, "Dec -> early Jan perihelion should move closer still")

        // Increasing out of perihelion toward aphelion.
        #expect(samples[2].km < samples[3].km, "early Jan -> Feb should move away from the Sun")
        #expect(samples[3].km < samples[4].km, "Feb -> Apr should keep moving away from the Sun")
        #expect(samples[4].km < samples[5].km, "Apr -> early Jul aphelion should move away from the Sun")

        // Decreasing again after aphelion, back toward the following winter.
        #expect(samples[5].km > samples[6].km, "early Jul aphelion -> Sep should move back toward the Sun")

        // The January sample is the overall minimum and the July sample the overall maximum.
        let minSample = samples.min { $0.km < $1.km }!
        let maxSample = samples.max { $0.km < $1.km }!
        #expect(minSample.label == "2026-01-04 (perihelion)", "expected perihelion sample to be the closest, got \(minSample.label)")
        #expect(maxSample.label == "2026-07-05 (aphelion)", "expected aphelion sample to be the farthest, got \(maxSample.label)")
    }
}
