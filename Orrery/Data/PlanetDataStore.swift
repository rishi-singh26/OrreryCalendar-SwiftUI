//
//  PlanetDataStore.swift
//  Orrery
//
//  A single cached record holding the packed per-day binary blob for the currently
//  computed date range (spec §4). Deliberately one record, not one object per day —
//  thousands of individual model instances would be far slower to query/hold in memory
//  than a single `Data` blob decoded into an in-memory lookup once at launch.
//

import Foundation
import SwiftData

@Model
final class PlanetDataStore {
    var startDate: Date // UTC midnight, first cached day
    var endDate: Date // UTC midnight, last cached day
    var dayCount: Int
    var bodies: [String] // fixed order, matches packed data layout
    var bytesPerDay: Int
    var distanceScale: Double
    var angleScale: Double
    var moonPhaseScale: Double
    var packedData: Data
    var formatVersion: Int // bumped if the packed byte layout ever changes
    var lastUpdated: Date

    /// Bump this if the packed byte layout ever changes. A mismatch at launch triggers
    /// a full recompute rather than misreading old bytes under a new interpretation.
    static let currentFormatVersion = 1

    init(startDate: Date, endDate: Date, dayCount: Int, packedData: Data) {
        self.startDate = startDate
        self.endDate = endDate
        self.dayCount = dayCount
        self.bodies = PlanetEngineClient.bodyNames
        self.bytesPerDay = PlanetEngineClient.bytesPerDay
        self.distanceScale = PlanetEngineClient.distanceScale
        self.angleScale = PlanetEngineClient.angleScale
        self.moonPhaseScale = PlanetEngineClient.moonPhaseScale
        self.packedData = packedData
        self.formatVersion = Self.currentFormatVersion
        self.lastUpdated = Date()
    }
}
