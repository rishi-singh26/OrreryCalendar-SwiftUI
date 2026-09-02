//
//  PlanetEngineClient.swift
//  Orrery
//
//  Per-day loop over the vendored Astronomy Engine, producing the packed binary layout
//  (spec §4): for each UTC calendar day, 8 planets' distance (AU×1000, UInt16LE) +
//  ecliptic longitude (deg×100, UInt16LE), then the Moon phase (deg×100, UInt16LE).
//  34 bytes/day total. Pure computation — no SwiftData, no main-thread assumptions —
//  safe to call from a background Task.
//

import Foundation
import AstronomyEngineSwift

nonisolated enum PlanetEngineClient {
    /// Fixed body order backing the packed layout. Do not reorder casually — every
    /// stored blob depends on this order matching `PlanetDataStore.bodies`.
    static let bodies = orderedPlanets
    static let bodyNames = bodies.map(\.rawValue)

    static let distanceScale = 1000.0
    static let angleScale = 100.0
    static let moonPhaseScale = 100.0
    static let bytesPerDay = bodies.count * 4 + 2 // 8×(2+2) + 2 = 34

    /// Computes the packed blob for the inclusive UTC day range [start, end].
    static func computePackedData(fromUTCDay start: Date, throughUTCDay end: Date) throws -> Data {
        let normalizedStart = UTCDay.midnight(of: start)
        let normalizedEnd = UTCDay.midnight(of: end)
        let dayCount = try UTCDay.dayCount(from: normalizedStart, to: normalizedEnd) + 1
        guard dayCount > 0 else {
            throw DataLayerError(message: "end date (\(normalizedEnd)) precedes start date (\(normalizedStart))")
        }

        var data = Data(capacity: dayCount * bytesPerDay)
        for offset in 0..<dayCount {
            guard let day = UTCDay.calendar.date(byAdding: .day, value: offset, to: normalizedStart) else {
                throw DataLayerError(message: "failed to advance date at day offset \(offset)")
            }
            // Converted once per day and reused for all 17 queries below (8 bodies ×
            // distance/angle + Moon phase), rather than re-running the UTC calendar
            // conversion inside every individual query for the same instant.
            let time = AstronomyEngine.time(for: day)

            for body in bodies {
                // Defensive per spec: check each call's status and skip (zero-fill)
                // rather than let one bad date wedge the whole batch. In practice this
                // should never fire for the Sun, 8 planets, and Moon across any
                // realistic calendar range.
                let distanceAU = (try? AstronomyEngine.helioDistance(body: body, time: time)) ?? 0
                let angleDeg = (try? AstronomyEngine.eclipticLongitude(body: body, time: time)) ?? 0
                data.appendUInt16LE(packedUInt16(distanceAU * distanceScale))
                data.appendUInt16LE(packedUInt16(angleDeg * angleScale))
            }

            let moonPhaseDeg = (try? AstronomyEngine.moonPhase(time: time)) ?? 0
            data.appendUInt16LE(packedUInt16(moonPhaseDeg * moonPhaseScale))
        }
        return data
    }

    private static func packedUInt16(_ value: Double) -> UInt16 {
        guard value.isFinite else { return 0 }
        let rounded = value.rounded()
        if rounded <= 0 { return 0 }
        if rounded >= Double(UInt16.max) { return UInt16.max }
        return UInt16(rounded)
    }
}

nonisolated extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    /// Reads a little-endian UInt16 at byte offset `index`. Returns `nil` if out of
    /// bounds rather than trapping — callers use this to guard against a
    /// truncated/corrupt blob at the array boundaries.
    func readUInt16LE(at index: Int) -> UInt16? {
        guard index >= 0, index + 1 < count else { return nil }
        let lo = UInt16(self[startIndex + index])
        let hi = UInt16(self[startIndex + index + 1])
        return lo | (hi << 8)
    }
}
