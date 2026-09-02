//
//  AppStorageKeys.swift
//  Orrery
//
//  Centralized `@AppStorage` key names (spec §6) so every view that reads/writes one of
//  these settings stays in sync automatically.
//

enum AppStorageKeys {
    static let showOrbits = "showOrbits"
    static let smallMoon = "smallMoon"
    static let appearanceMode = "appearanceMode"
    static let rangeYears = "rangeYears"
}
