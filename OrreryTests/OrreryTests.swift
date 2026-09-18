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

    // MARK: - OrreryGeometry.interpolatedAngleDeg (sweep direction)
    //
    // `interpolatedAngleDeg` must sweep in the *given* direction even when that's not
    // the shorter arc — this is what makes `OrreryView`'s launch entrance always
    // clockwise and its date-jump transitions forward/backward-in-time-aware, rather
    // than picking whichever way happens to be shorter.

    /// Normalizes an angle into `[0, 360)` — `interpolatedAngleDeg` doesn't itself wrap
    /// its output into that range (its raw result can exceed 360 or go negative), so
    /// tests compare against the normalized form when checking *which* angle a raw
    /// result represents.
    private static func normalizedDeg(_ deg: Double) -> Double {
        let m = deg.truncatingRemainder(dividingBy: 360)
        return m < 0 ? m + 360 : m
    }

    @Test func interpolatedAngleDeg_counterClockwise_shortForwardSweep_crossesZeroBoundary() throws {
        // 350° -> 10°: the short way is 20° forward (increasing, crossing the 360°/0°
        // boundary), which also happens to be the counter-clockwise direction here.
        let start = 350.0
        let end = 10.0
        var previous = start
        for step in 1...10 {
            let progress = Double(step) / 10
            let angle = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: progress, direction: .counterClockwise)
            #expect(angle > previous, "counter-clockwise sweep should keep increasing, got \(angle) after \(previous)")
            previous = angle
        }
        #expect(abs(Self.normalizedDeg(previous) - end) < 0.0001)
    }

    @Test func interpolatedAngleDeg_clockwise_shortBackwardSweep_crossesZeroBoundary() throws {
        // 10° -> 350°: the short way is 20° backward (decreasing, crossing the
        // 360°/0° boundary), which also happens to be the clockwise direction here.
        let start = 10.0
        let end = 350.0
        var previous = start
        for step in 1...10 {
            let progress = Double(step) / 10
            let angle = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: progress, direction: .clockwise)
            #expect(angle < previous, "clockwise sweep should keep decreasing, got \(angle) after \(previous)")
            previous = angle
        }
        #expect(abs(Self.normalizedDeg(previous) - end) < 0.0001)
    }

    @Test func interpolatedAngleDeg_counterClockwise_forcedTheLongWayWhenShortPathIsClockwise() throws {
        // 10° -> 350°: the *short* path is clockwise (20°, backward). Forcing
        // counter-clockwise must instead take the long way around (340°, forward),
        // so the midpoint should land on the far side, near 180°, not near 190°.
        let start = 10.0
        let end = 350.0
        let midpoint = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 0.5, direction: .counterClockwise)
        #expect(abs(Self.normalizedDeg(midpoint) - 180) < 0.0001, "expected the long-way midpoint near 180°, got \(Self.normalizedDeg(midpoint))")
        let atOne = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 1, direction: .counterClockwise)
        #expect(abs(Self.normalizedDeg(atOne) - end) < 0.0001)
    }

    @Test func interpolatedAngleDeg_clockwise_forcedTheLongWayWhenShortPathIsCounterClockwise() throws {
        // 350° -> 10°: the *short* path is counter-clockwise (20°, forward). Forcing
        // clockwise must instead take the long way around (340°, backward), so the
        // midpoint should land on the far side, near 180°.
        let start = 350.0
        let end = 10.0
        let midpoint = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 0.5, direction: .clockwise)
        #expect(abs(Self.normalizedDeg(midpoint) - 180) < 0.0001, "expected the long-way midpoint near 180°, got \(Self.normalizedDeg(midpoint))")
        let atOne = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 1, direction: .clockwise)
        #expect(abs(Self.normalizedDeg(atOne) - end) < 0.0001)
    }

    @Test func interpolatedAngleDeg_sameAngle_staysPutRegardlessOfDirection() throws {
        // Equal angles (including two different representations of the same angle,
        // 0° and 360°) must not produce a spurious full-circle sweep in either
        // direction.
        let pairs: [(Double, Double)] = [(42, 42), (0, 360), (360, 0)]
        let directions: [OrreryGeometry.SweepDirection] = [.clockwise, .counterClockwise]
        for (start, end) in pairs {
            for direction in directions {
                for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    let result = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: progress, direction: direction)
                    #expect(abs(result - start) < 0.0001, "\(direction) at progress \(progress) from \(start) to \(end) should stay put, got \(result)")
                }
            }
        }
    }

    @Test func interpolatedAngleDeg_endpoints_matchStartAndEnd() throws {
        let start = 200.0
        let end = 40.0
        for direction: OrreryGeometry.SweepDirection in [.clockwise, .counterClockwise] {
            let atZero = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 0, direction: direction)
            let atOne = OrreryGeometry.interpolatedAngleDeg(from: start, to: end, progress: 1, direction: direction)
            #expect(abs(atZero - start) < 0.0001)
            #expect(abs(Self.normalizedDeg(atOne) - Self.normalizedDeg(end)) < 0.0001)
        }
    }

    // MARK: - ScrubTimelineMath boundary-tick computations (Orrery/Views/ScrubTimelineMath.swift)

    /// Naive, unoptimized reference implementation of `weekStartIndices` — the shape
    /// the production code used before being optimized to do one `Calendar` lookup
    /// total instead of one per week. Used only to cross-check the optimized version
    /// produces identical output, so the optimization can't have silently changed
    /// which days get marked as boundary ticks.
    private static func naiveWeekStartIndices(minDate: Date, maxDate: Date) -> Set<Int> {
        guard maxDate >= minDate else { return [] }
        let calendar = UTCDay.calendar
        var indices = Set<Int>()
        var cursor = calendar.dateInterval(of: .weekOfYear, for: minDate)?.start ?? minDate
        while cursor <= maxDate {
            if cursor >= minDate, let idx = try? UTCDay.dayCount(from: minDate, to: cursor) {
                indices.insert(idx)
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return indices
    }

    @Test func weekStartIndices_matchesNaiveCalendarWalk_acrossVariedRanges() throws {
        let cases: [(minDate: Date, maxDate: Date)] = [
            // minDate exactly on a week start (2026-01-04 is a Sunday).
            (Self.utcDate(year: 2026, month: 1, day: 4), Self.utcDate(year: 2026, month: 3, day: 1)),
            // minDate mid-week (a Wednesday).
            (Self.utcDate(year: 2026, month: 1, day: 7), Self.utcDate(year: 2026, month: 3, day: 1)),
            // A short range with no week boundary inside it at all.
            (Self.utcDate(year: 2026, month: 1, day: 7), Self.utcDate(year: 2026, month: 1, day: 9)),
            // Degenerate single-day range.
            (Self.utcDate(year: 2026, month: 1, day: 7), Self.utcDate(year: 2026, month: 1, day: 7)),
            // A multi-year range spanning a leap year, to exercise many weeks at once.
            (Self.utcDate(year: 2024, month: 1, day: 1), Self.utcDate(year: 2029, month: 1, day: 1)),
        ]

        for (minDate, maxDate) in cases {
            let optimized = ScrubTimelineMath.weekStartIndices(minDate: minDate, maxDate: maxDate)
            let naive = Self.naiveWeekStartIndices(minDate: minDate, maxDate: maxDate)
            #expect(optimized == naive, "mismatch for \(minDate)...\(maxDate): optimized has \(optimized.count) indices, naive has \(naive.count)")
        }
    }

    @Test func weekStartIndices_alignsToUTCCalendarSunday() throws {
        // `UTCDay.calendar` has no explicit locale, so its `firstWeekday` must be the
        // locale-independent Gregorian default (1 == Sunday) for "Weekly" boundary
        // ticks to land on a consistent, predictable weekday for every user.
        #expect(UTCDay.calendar.firstWeekday == 1)

        // 2026-01-04 is a Sunday; every 7th day after it should be a boundary index.
        let minDate = Self.utcDate(year: 2026, month: 1, day: 4)
        let maxDate = Self.utcDate(year: 2026, month: 2, day: 1)
        let indices = ScrubTimelineMath.weekStartIndices(minDate: minDate, maxDate: maxDate)
        #expect(indices == [0, 7, 14, 21, 28])
    }

    @Test func fixedCadenceIndices_alwaysIncludesMinDateAndSteps() throws {
        let minDate = Self.utcDate(year: 2026, month: 1, day: 1)
        let maxDate = Self.utcDate(year: 2026, month: 2, day: 1) // 31 days later

        let every10 = ScrubTimelineMath.fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 10)
        #expect(every10 == [0, 10, 20, 30])

        let every15 = ScrubTimelineMath.fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 15)
        #expect(every15 == [0, 15, 30])
    }

    @Test func crossesBoundary_excludesFromIndexIncludesToIndex_bothDirections() throws {
        let boundaries: Set<Int> = [0, 10, 20]

        // Landing exactly on a boundary fires, in either direction.
        #expect(ScrubTimelineMath.crossesBoundary(fromIndex: 9, toIndex: 10, boundaryIndices: boundaries))
        #expect(ScrubTimelineMath.crossesBoundary(fromIndex: 11, toIndex: 10, boundaryIndices: boundaries))
        // Moving away from a boundary already landed on does not re-fire.
        #expect(!ScrubTimelineMath.crossesBoundary(fromIndex: 10, toIndex: 12, boundaryIndices: boundaries))
        #expect(!ScrubTimelineMath.crossesBoundary(fromIndex: 10, toIndex: 8, boundaryIndices: boundaries))
        // A multi-day jump that passes over (without landing exactly on) a boundary still fires.
        #expect(ScrubTimelineMath.crossesBoundary(fromIndex: 5, toIndex: 15, boundaryIndices: boundaries))
        // No boundary anywhere in the traversed range.
        #expect(!ScrubTimelineMath.crossesBoundary(fromIndex: 1, toIndex: 3, boundaryIndices: boundaries))
        // No-op (same index) never fires.
        #expect(!ScrubTimelineMath.crossesBoundary(fromIndex: 10, toIndex: 10, boundaryIndices: boundaries))
    }

    @Test func boundaryIndices_dispatchesToTheRightFrequency() throws {
        let minDate = Self.utcDate(year: 2026, month: 1, day: 4) // a Sunday
        let maxDate = Self.utcDate(year: 2026, month: 2, day: 1)
        #expect(ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: .weekly)
                == ScrubTimelineMath.weekStartIndices(minDate: minDate, maxDate: maxDate))
        #expect(ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: .monthly)
                == ScrubTimelineMath.monthStartIndices(minDate: minDate, maxDate: maxDate))
        #expect(ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: .every10Days)
                == ScrubTimelineMath.fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 10))
        #expect(ScrubTimelineMath.boundaryIndices(minDate: minDate, maxDate: maxDate, frequency: .every15Days)
                == ScrubTimelineMath.fixedCadenceIndices(minDate: minDate, maxDate: maxDate, intervalDays: 15))
    }

    @Test func boundaryTickFrequency_persistedFallsBackToDefaultAndRoundTrips() throws {
        let key = AppStorageKeys.boundaryTickFrequency
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(BoundaryTickFrequency.persisted == BoundaryTickFrequency.defaultFrequency)

        UserDefaults.standard.set(BoundaryTickFrequency.weekly.rawValue, forKey: key)
        #expect(BoundaryTickFrequency.persisted == .weekly)
    }

}
