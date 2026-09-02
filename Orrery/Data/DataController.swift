//
//  DataController.swift
//  Orrery
//
//  Owns the decoded in-memory lookup the UI reads from, and drives computing/caching
//  the packed `PlanetDataStore` blob (spec §4). All SwiftData I/O goes through the
//  background `DataStoreIO` actor; this type is main-actor-isolated and safe for
//  SwiftUI views to observe directly.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class DataController {
    static let minRangeYears = 1
    static let maxRangeYears = 100
    static let defaultRangeYears = 10

    private(set) var startDate: Date = UTCDay.todayAsUTCMidnight()
    private(set) var endDate: Date = UTCDay.todayAsUTCMidnight()
    private(set) var dayCount: Int = 0
    private(set) var isComputing = false
    private(set) var isReady = false
    private(set) var lastErrorMessage: String?

    private var snapshots: [DaySnapshot] = []
    private var packedDataCache = Data()
    private let io: DataStoreIO
    private var computeTask: Task<Void, Never>?

    /// Years currently covered on each side of today, rounded down — used to render
    /// e.g. "±10 years" in Settings.
    var coveredYears: Int {
        guard isReady else { return 0 }
        let days = (try? UTCDay.dayCount(from: startDate, to: UTCDay.todayAsUTCMidnight())) ?? 0
        return abs(days) / 365
    }

    var todayDate: Date { UTCDay.todayAsUTCMidnight() }

    init(modelContainer: ModelContainer) {
        self.io = DataStoreIO(container: modelContainer)
    }

    // MARK: - Launch

    /// Call once at app launch. Loads the cached store if present and its format
    /// version still matches; otherwise computes the default ±10-year range in the
    /// background. Never recomputes an already-valid cached range — a given calendar
    /// date's positions are deterministic and never change.
    func bootstrap() async {
        do {
            if let snapshot = try await io.loadStore() {
                await apply(snapshot)
                isReady = true
            } else {
                await computeFullRange(years: Self.defaultRangeYears)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Detects a range setting that doesn't match what's actually cached — e.g. the app
    /// was terminated mid-extension — and resumes rather than silently under-reporting
    /// the range. Safe to call every launch; a no-op once the cache already covers
    /// `desiredYears`. Call after `bootstrap()` completes.
    func resumeRangeIfNeeded(desiredYears: Int) {
        guard isReady, !isComputing else { return }
        let years = clampedYears(desiredYears)
        let today = UTCDay.todayAsUTCMidnight()
        guard
            let desiredStart = UTCDay.calendar.date(byAdding: .year, value: -years, to: today),
            let desiredEnd = UTCDay.calendar.date(byAdding: .year, value: years, to: today)
        else { return }
        if desiredStart < startDate || desiredEnd > endDate {
            extendRange(toYears: years)
        }
    }

    // MARK: - Lookup

    func snapshot(for date: Date) -> DaySnapshot? {
        guard isReady else { return nil }
        let day = UTCDay.midnight(of: date)
        guard
            let offset = try? UTCDay.dayCount(from: startDate, to: day),
            snapshots.indices.contains(offset)
        else { return nil }
        return snapshots[offset]
    }

    /// Clamps `date` into the currently cached range (UTC-day-normalized). The scrub
    /// timeline and date picker both route through this so they can never request a
    /// day outside the cache.
    func clampedDate(_ date: Date) -> Date {
        let day = UTCDay.midnight(of: date)
        return min(max(day, startDate), endDate)
    }

    // MARK: - Range extension

    /// Extends the cached range to ±`years` around today. Computes only the new
    /// sub-range(s) not already covered and splices them onto the existing blob —
    /// never recomputes what's already cached. Ignored while a computation is already
    /// in flight; the Settings range control disables itself using `isComputing` so a
    /// second one can't be launched from the UI, and this guard backstops that.
    func extendRange(toYears years: Int) {
        guard !isComputing else { return }
        let years = clampedYears(years)
        let today = UTCDay.todayAsUTCMidnight()
        guard
            let requestedStart = UTCDay.calendar.date(byAdding: .year, value: -years, to: today),
            let requestedEnd = UTCDay.calendar.date(byAdding: .year, value: years, to: today)
        else { return }

        guard isReady else {
            computeTask = Task { await self.computeFullRange(start: requestedStart, end: requestedEnd) }
            return
        }

        let newStart = min(requestedStart, startDate)
        let newEnd = max(requestedEnd, endDate)
        guard newStart < startDate || newEnd > endDate else { return } // already fully covered

        computeTask = Task { await self.splice(newStart: newStart, newEnd: newEnd) }
    }

    private func clampedYears(_ years: Int) -> Int {
        min(max(years, Self.minRangeYears), Self.maxRangeYears)
    }

    private func computeFullRange(years: Int) async {
        let today = UTCDay.todayAsUTCMidnight()
        guard
            let start = UTCDay.calendar.date(byAdding: .year, value: -years, to: today),
            let end = UTCDay.calendar.date(byAdding: .year, value: years, to: today)
        else { return }
        await computeFullRange(start: start, end: end)
    }

    private func computeFullRange(start: Date, end: Date) async {
        isComputing = true
        lastErrorMessage = nil
        do {
            let packed = try await Task.detached(priority: .userInitiated) {
                try PlanetEngineClient.computePackedData(fromUTCDay: start, throughUTCDay: end)
            }.value
            let count = try UTCDay.dayCount(from: start, to: end) + 1
            try await io.replaceStore(startDate: start, endDate: end, dayCount: count, packedData: packed)
            await apply(StoreSnapshot(
                startDate: start, endDate: end, dayCount: count,
                bodies: PlanetEngineClient.bodyNames, bytesPerDay: PlanetEngineClient.bytesPerDay,
                distanceScale: PlanetEngineClient.distanceScale, angleScale: PlanetEngineClient.angleScale,
                moonPhaseScale: PlanetEngineClient.moonPhaseScale, packedData: packed,
                formatVersion: PlanetDataStore.currentFormatVersion
            ))
            isReady = true
        } catch {
            // Disk-write / compute failure: keep whatever was previously cached (untouched,
            // since the store is only ever replaced atomically) and surface for a retry
            // affordance in Settings rather than crashing or discarding data.
            lastErrorMessage = error.localizedDescription
        }
        isComputing = false
    }

    private func splice(newStart: Date, newEnd: Date) async {
        isComputing = true
        lastErrorMessage = nil
        let existingStart = startDate
        let existingEnd = endDate
        let existingPacked = packedDataCache
        do {
            var beforeData = Data()
            if newStart < existingStart {
                let beforeEnd = UTCDay.previousDay(before: existingStart)
                beforeData = try await Task.detached(priority: .userInitiated) {
                    try PlanetEngineClient.computePackedData(fromUTCDay: newStart, throughUTCDay: beforeEnd)
                }.value
            }

            var afterData = Data()
            if newEnd > existingEnd {
                let afterStart = UTCDay.nextDay(after: existingEnd)
                afterData = try await Task.detached(priority: .userInitiated) {
                    try PlanetEngineClient.computePackedData(fromUTCDay: afterStart, throughUTCDay: newEnd)
                }.value
            }

            var fullBlob = Data(capacity: beforeData.count + existingPacked.count + afterData.count)
            fullBlob.append(beforeData)
            fullBlob.append(existingPacked)
            fullBlob.append(afterData)

            let count = try UTCDay.dayCount(from: newStart, to: newEnd) + 1
            try await io.replaceStore(startDate: newStart, endDate: newEnd, dayCount: count, packedData: fullBlob)
            await apply(StoreSnapshot(
                startDate: newStart, endDate: newEnd, dayCount: count,
                bodies: PlanetEngineClient.bodyNames, bytesPerDay: PlanetEngineClient.bytesPerDay,
                distanceScale: PlanetEngineClient.distanceScale, angleScale: PlanetEngineClient.angleScale,
                moonPhaseScale: PlanetEngineClient.moonPhaseScale, packedData: fullBlob,
                formatVersion: PlanetDataStore.currentFormatVersion
            ))
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        isComputing = false
    }

    private func apply(_ snapshot: StoreSnapshot) async {
        startDate = snapshot.startDate
        endDate = snapshot.endDate
        dayCount = snapshot.dayCount
        packedDataCache = snapshot.packedData
        snapshots = await Task.detached(priority: .userInitiated) {
            Self.decode(snapshot)
        }.value
    }

    /// Pure decode, safe to run off the main actor. Guards against a truncated/corrupt
    /// blob at the array boundary by stopping cleanly rather than trapping.
    nonisolated private static func decode(_ snapshot: StoreSnapshot) -> [DaySnapshot] {
        guard snapshot.dayCount > 0 else { return [] }
        var result: [DaySnapshot] = []
        result.reserveCapacity(snapshot.dayCount)
        let data = snapshot.packedData

        for day in 0..<snapshot.dayCount {
            guard let date = UTCDay.calendar.date(byAdding: .day, value: day, to: snapshot.startDate) else {
                break
            }
            var offset = day * snapshot.bytesPerDay
            var planets: [PlanetValue] = []
            planets.reserveCapacity(snapshot.bodies.count)
            var truncated = false

            for name in snapshot.bodies {
                guard
                    let rawDistance = data.readUInt16LE(at: offset),
                    let rawAngle = data.readUInt16LE(at: offset + 2)
                else {
                    truncated = true
                    break
                }
                offset += 4
                planets.append(PlanetValue(
                    name: name,
                    distanceAU: Double(rawDistance) / snapshot.distanceScale,
                    angleDeg: Double(rawAngle) / snapshot.angleScale
                ))
            }

            guard !truncated, let rawMoon = data.readUInt16LE(at: offset) else { break }
            result.append(DaySnapshot(
                date: date,
                planets: planets,
                moonPhaseDeg: Double(rawMoon) / snapshot.moonPhaseScale
            ))
        }
        return result
    }
}
