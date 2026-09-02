//
//  OrreryTests.swift
//  OrreryTests
//
//  Created by Rishi Singh on 02/09/26.
//

import Testing
import Foundation
@testable import AstronomyEngineSwift
@testable import Orrery

struct OrreryTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    // MARK: - AstronomyEngine reference values (spec §4)
    //
    // Confirmed-correct reference values for 2026-01-04 UTC, carried over from the
    // already-validated web prototype. If these don't match within ~0.01, something in
    // the port is wired wrong (wrong body enum, wrong angle convention, wrong time
    // construction) and must be fixed before anything downstream is trusted.

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    @Test func referenceValues_2026_01_04() throws {
        let date = Self.utcDate(year: 2026, month: 1, day: 4)

        let expected: [(CelestialBody, Double, Double)] = [
            (.mercury, 0.4659, 250.92),
            (.venus, 0.7276, 282.13),
            (.earth, 0.9833, 103.63),
            (.mars, 1.4256, 285.95),
            (.jupiter, 5.2131, 109.58),
            (.saturn, 9.5178, 2.02),
            (.uranus, 19.4894, 59.94),
            (.neptune, 29.8853, 1.38),
        ]

        for (body, expectedAU, expectedDeg) in expected {
            let au = try AstronomyEngine.helioDistance(body: body, date: date)
            let deg = try AstronomyEngine.eclipticLongitude(body: body, date: date)
            #expect(abs(au - expectedAU) < 0.01, "\(body) distance: got \(au), expected \(expectedAU)")
            #expect(abs(deg - expectedDeg) < 0.01, "\(body) angle: got \(deg), expected \(expectedDeg)")
        }

        let moonPhase = try AstronomyEngine.moonPhase(date: date)
        #expect(abs(moonPhase - 188.01) < 0.01, "moon phase: got \(moonPhase), expected 188.01")
    }

    // MARK: - Data layer edge cases (spec §4, §9)

    /// "Today" must resolve from the device's *local* calendar day, not whatever UTC's
    /// date happens to be — otherwise a user far from UTC sees the wrong physical day.
    @Test func todayResolution_farFromUTC() throws {
        // UTC+13: local time is already tomorrow relative to UTC for part of the day.
        var aheadCalendar = Calendar(identifier: .gregorian)
        aheadCalendar.timeZone = TimeZone(identifier: "Pacific/Tongatapu")! // UTC+13
        // 2026-01-04 23:00 UTC == 2026-01-05 12:00 local (Tongatapu).
        let utcLateNight = Self.utcDate(year: 2026, month: 1, day: 4).addingTimeInterval(23 * 3600)
        let localDay = aheadCalendar.dateComponents([.year, .month, .day], from: utcLateNight)
        #expect(localDay.day == 5, "sanity: local day should already be the 5th in UTC+13")

        // UTC-11: local time lags a full calendar day behind UTC for part of the day.
        var behindCalendar = Calendar(identifier: .gregorian)
        behindCalendar.timeZone = TimeZone(identifier: "Pacific/Niue")! // UTC-11
        // 2026-01-05 02:00 UTC == 2026-01-04 15:00 local (Niue).
        let utcEarlyMorning = Self.utcDate(year: 2026, month: 1, day: 5).addingTimeInterval(2 * 3600)
        let localDayBehind = behindCalendar.dateComponents([.year, .month, .day], from: utcEarlyMorning)
        #expect(localDayBehind.day == 4, "sanity: local day should still be the 4th in UTC-11")

        // UTCDay.todayAsUTCMidnight(deviceCalendar:) must map each of these to the
        // *local* calendar day's UTC-keyed midnight, not the UTC calendar day.
        let resolvedAhead = UTCDay.todayAsUTCMidnight(deviceCalendar: aheadCalendar)
        let resolvedBehind = UTCDay.todayAsUTCMidnight(deviceCalendar: behindCalendar)
        // Both are computed from the *actual current moment*, so we can only assert
        // internal consistency: the resolved date's UTC day-of-month must equal the
        // local calendar's day-of-month at "now" for that time zone.
        let nowInAhead = aheadCalendar.dateComponents([.year, .month, .day], from: Date())
        let nowInBehind = behindCalendar.dateComponents([.year, .month, .day], from: Date())
        let resolvedAheadComponents = UTCDay.calendar.dateComponents([.year, .month, .day], from: resolvedAhead)
        let resolvedBehindComponents = UTCDay.calendar.dateComponents([.year, .month, .day], from: resolvedBehind)
        #expect(resolvedAheadComponents.day == nowInAhead.day)
        #expect(resolvedAheadComponents.month == nowInAhead.month)
        #expect(resolvedAheadComponents.year == nowInAhead.year)
        #expect(resolvedBehindComponents.day == nowInBehind.day)
        #expect(resolvedBehindComponents.month == nowInBehind.month)
        #expect(resolvedBehindComponents.year == nowInBehind.year)
    }

    @Test func dayCount_leapYearHandledByCalendar() throws {
        // 2026-01-01 -> 2027-01-01 spans all of 2026, which is not a leap year (365
        // days). 2028-01-01 -> 2029-01-01 spans all of 2028, which is (Feb 29 2028
        // exists, 366 days). Calendar-based day counting must reflect that
        // automatically rather than assuming 365 days per year.
        let nonLeapStart = Self.utcDate(year: 2026, month: 1, day: 1)
        let nonLeapEnd = Self.utcDate(year: 2027, month: 1, day: 1)
        let leapStart = Self.utcDate(year: 2028, month: 1, day: 1)
        let leapEnd = Self.utcDate(year: 2029, month: 1, day: 1)
        let nonLeapSpan = try UTCDay.dayCount(from: nonLeapStart, to: nonLeapEnd)
        let leapSpan = try UTCDay.dayCount(from: leapStart, to: leapEnd)
        #expect(nonLeapSpan == 365)
        #expect(leapSpan == 366)
    }

    /// The first and last day of a packed blob must decode correctly — off-by-one
    /// errors at array/blob boundaries are the most common bug class here.
    @Test func packedData_boundaryDaysDecodeCorrectly() throws {
        let start = Self.utcDate(year: 2026, month: 1, day: 4)
        let end = Self.utcDate(year: 2026, month: 1, day: 10) // 7 days inclusive
        let packed = try PlanetEngineClient.computePackedData(fromUTCDay: start, throughUTCDay: end)
        let dayCount = try UTCDay.dayCount(from: start, to: end) + 1
        #expect(dayCount == 7)
        #expect(packed.count == dayCount * PlanetEngineClient.bytesPerDay)

        // First day's first field (Mercury distance×1000) should match the direct
        // engine call for `start`.
        let firstRawDistance = packed.readUInt16LE(at: 0)
        let directFirstDistance = try AstronomyEngine.helioDistance(body: .mercury, date: start)
        #expect(firstRawDistance != nil)
        #expect(abs(Double(firstRawDistance!) / PlanetEngineClient.distanceScale - directFirstDistance) < 0.01)

        // Last day's moon-phase field (final 2 bytes of the blob) should match the
        // direct engine call for `end`.
        let lastDayBase = (dayCount - 1) * PlanetEngineClient.bytesPerDay
        let lastMoonOffset = lastDayBase + PlanetEngineClient.bytesPerDay - 2
        let lastRawMoon = packed.readUInt16LE(at: lastMoonOffset)
        let directLastMoon = try AstronomyEngine.moonPhase(date: end)
        #expect(lastRawMoon != nil)
        #expect(abs(Double(lastRawMoon!) / PlanetEngineClient.moonPhaseScale - directLastMoon) < 0.01)

        // Reading just past the end of the blob must fail gracefully, not trap.
        #expect(packed.readUInt16LE(at: packed.count - 1) == nil)
        #expect(packed.readUInt16LE(at: packed.count) == nil)
    }

    // MARK: - MoonPhaseShape checkpoints (spec §2)

    /// Even-odd point-in-polygon test over a sample grid, used to measure the shape's
    /// lit area without needing a rendering context.
    private static func litFraction(vertices: [CGPoint], radius r: Double, gridSize: Int = 200) -> Double {
        guard !vertices.isEmpty else { return 0 }
        var insideCount = 0
        var totalCount = 0
        for gy in 0..<gridSize {
            for gx in 0..<gridSize {
                let x = -r + (Double(gx) + 0.5) / Double(gridSize) * (2 * r)
                let y = -r + (Double(gy) + 0.5) / Double(gridSize) * (2 * r)
                guard x * x + y * y <= r * r else { continue } // only sample inside the disc
                totalCount += 1
                if pointInPolygon(CGPoint(x: x, y: y), vertices) {
                    insideCount += 1
                }
            }
        }
        guard totalCount > 0 else { return 0 }
        return Double(insideCount) / Double(totalCount)
    }

    private static func pointInPolygon(_ point: CGPoint, _ polygon: [CGPoint]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let vi = polygon[i]
            let vj = polygon[j]
            if (vi.y > point.y) != (vj.y > point.y) {
                let slope = (point.x - vi.x) * (vj.y - vi.y) - (vj.x - vi.x) * (point.y - vi.y)
                if slope == 0 { return true }
                if (slope < 0) != (vj.y < vi.y) {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    /// Centroid x of the lit region — used to confirm *which* half is lit at the two
    /// "half lit" checkpoints, so waxing vs. waning can't be silently swapped.
    private static func litCentroidX(vertices: [CGPoint], radius r: Double, gridSize: Int = 200) -> Double {
        var sumX = 0.0
        var count = 0
        for gy in 0..<gridSize {
            for gx in 0..<gridSize {
                let x = -r + (Double(gx) + 0.5) / Double(gridSize) * (2 * r)
                let y = -r + (Double(gy) + 0.5) / Double(gridSize) * (2 * r)
                guard x * x + y * y <= r * r else { continue }
                if pointInPolygon(CGPoint(x: x, y: y), vertices) {
                    sumX += x
                    count += 1
                }
            }
        }
        guard count > 0 else { return 0 }
        return sumX / Double(count)
    }

    @Test func moonPhaseShape_newMoon_isDegenerate() throws {
        let r = 50.0
        let vertices = MoonPhaseShape.vertices(fraction: 0.0, radius: r, sampleCount: 64)
        let lit = Self.litFraction(vertices: vertices, radius: r)
        let expectedK = (1 - cos(0.0 * 2 * .pi)) / 2
        #expect(expectedK == 0)
        #expect(lit < 0.02, "new moon should be ~0% illuminated, got \(lit)")
    }

    @Test func moonPhaseShape_firstQuarter_rightHalfLit() throws {
        let r = 50.0
        let vertices = MoonPhaseShape.vertices(fraction: 0.25, radius: r, sampleCount: 64)
        let lit = Self.litFraction(vertices: vertices, radius: r)
        #expect(abs(lit - 0.5) < 0.03, "first quarter should be ~50% illuminated, got \(lit)")
        let centroidX = Self.litCentroidX(vertices: vertices, radius: r)
        #expect(centroidX > 0, "first quarter (waxing) should light the right half, centroid x = \(centroidX)")
    }

    @Test func moonPhaseShape_fullMoon_entireDiscLit() throws {
        let r = 50.0
        let vertices = MoonPhaseShape.vertices(fraction: 0.5, radius: r, sampleCount: 64)
        let lit = Self.litFraction(vertices: vertices, radius: r)
        let expectedK = (1 - cos(0.5 * 2 * .pi)) / 2
        #expect(expectedK == 1)
        #expect(lit > 0.97, "full moon should be ~100% illuminated, got \(lit)")
    }

    @Test func moonPhaseShape_lastQuarter_leftHalfLit() throws {
        let r = 50.0
        let vertices = MoonPhaseShape.vertices(fraction: 0.75, radius: r, sampleCount: 64)
        let lit = Self.litFraction(vertices: vertices, radius: r)
        #expect(abs(lit - 0.5) < 0.03, "last quarter should be ~50% illuminated, got \(lit)")
        let centroidX = Self.litCentroidX(vertices: vertices, radius: r)
        #expect(centroidX < 0, "last quarter (waning) should light the left half, centroid x = \(centroidX)")
    }

    // MARK: - ScrollDayAccumulator (scroll-wheel smoothness fix)

    /// Many small deltas (well under one day each) must still add up to whole-day steps
    /// — this is the exact bug that made scroll-wheel input feel dead: rounding each
    /// event independently drops almost all of them.
    @Test func scrollAccumulator_manySmallDeltasSumToWholeDays() {
        var accumulator = ScrollDayAccumulator()
        let pointsPerDay = 10.0
        var totalDaysStepped = 0
        // 50 events of 0.3pt each = 15pt total = 1.5 days worth of input.
        for _ in 0..<50 {
            totalDaysStepped += accumulator.consume(deltaPoints: 0.3, pointsPerDay: pointsPerDay)
        }
        #expect(totalDaysStepped == 1, "1.5 days of accumulated input should have stepped once so far")
        #expect(abs(accumulator.remainder - 0.5) < 0.0001)
    }

    @Test func scrollAccumulator_singleTinyDeltaProducesNoStepButIsNotLost() {
        var accumulator = ScrollDayAccumulator()
        let stepped = accumulator.consume(deltaPoints: 0.3, pointsPerDay: 10.0)
        #expect(stepped == 0, "a single small delta shouldn't cross a whole day on its own")
        #expect(abs(accumulator.remainder - 0.03) < 0.0001, "but it must still be retained, not discarded")
    }

    @Test func scrollAccumulator_reversingDirectionCancelsPartialAccumulation() {
        var accumulator = ScrollDayAccumulator()
        _ = accumulator.consume(deltaPoints: 7, pointsPerDay: 10.0) // 0.7 days, no step yet
        let stepped = accumulator.consume(deltaPoints: -3, pointsPerDay: 10.0) // back to 0.4, still no step
        #expect(stepped == 0)
        #expect(abs(accumulator.remainder - 0.4) < 0.0001)
    }

    @Test func scrollAccumulator_resetDropsRemainder() {
        var accumulator = ScrollDayAccumulator()
        _ = accumulator.consume(deltaPoints: 9, pointsPerDay: 10.0)
        accumulator.reset()
        #expect(accumulator.remainder == 0)
    }

    @Test func scrollAccumulator_largeFastDeltaStepsMultipleDaysAtOnce() {
        var accumulator = ScrollDayAccumulator()
        let stepped = accumulator.consume(deltaPoints: 47, pointsPerDay: 10.0)
        #expect(stepped == 4)
        #expect(abs(accumulator.remainder - 0.7) < 0.0001)
    }
}
