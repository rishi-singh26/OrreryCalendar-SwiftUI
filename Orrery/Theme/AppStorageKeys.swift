//
//  AppStorageKeys.swift
//  Orrery
//
//  Centralized `@AppStorage` key names (spec §6) so every view that reads/writes one of
//  these settings stays in sync automatically.
//

enum AppStorageKeys {
    static let showOrbits = "showOrbits"
    static let showLabels = "showLabels"
    static let showSunHalo = "showSunHalo"
    static let moonSizeScrub = "moonSizeScrub"
    static let showMoonSizeScrubber = "showMoonSizeScrubber"
    static let appearanceMode = "appearanceMode"
    static let rangeYears = "rangeYears"
    static let boundaryTickFrequency = "boundaryTickFrequency"
    static let selectedPlanetIndex = "selectedPlanetIndex"
    static let syncPlanetDetailDate = "syncPlanetDetailDate"
    static let hapticsEnabled = "hapticsEnabled"
    static let autoPlayEnabled = "autoPlayEnabled"
    static let autoPlayRate = "autoPlayRate"
    static let autoPlayDirection = "autoPlayDirection"
    static let autoPlayManualChange = "autoPlayManualChange"
}
