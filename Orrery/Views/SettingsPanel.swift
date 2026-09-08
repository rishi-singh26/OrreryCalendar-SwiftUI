//
//  SettingsPanel.swift
//  Orrery
//
//  Settings content (spec §6). Presentation (sheet/popover/ornament) is handled by
//  `orrerySettingsPresentation(isPresented:)` below, adapting per platform.
//

import SwiftUI

struct SettingsPanel: View {
    @Environment(DataController.self) private var dataController

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show Orbits", isOn: $showOrbits)
                Toggle("Show Labels", isOn: $showLabels)
                Toggle("Show Sun Halo", isOn: $showSunHalo)
            }
            
            Section("Appearance") {
                Picker(selection: $appearanceMode) {
                    Label("System", systemImage: "iphone.gen2").tag(AppearanceMode.system)
                    Label("Light", systemImage: "sun.max").tag(AppearanceMode.light)
                    Label("Dark", systemImage: "moon.stars").tag(AppearanceMode.dark)
                } label: {
                    Label {
                        Text("Appearance")
                    } icon: {
                        AppearanceIconView(size: 24)
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            Section("Date range") {
                if dataController.isReady {
                    Text("Cached: \(rangeDescription)")
                        .foregroundStyle(.secondary)
                }

                Picker("Extend range", selection: rangeSelection) {
                    ForEach(Self.rangePresets, id: \.self) { years in
                        Text("±\(years) years").tag(years)
                    }
                }
                .disabled(dataController.isComputing)

                if dataController.isComputing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Computing…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = dataController.lastErrorMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(ThemeColors.errorText)
                        Button("Retry") {
                            dataController.setRange(toYears: rangeYears)
                        }
                        .disabled(dataController.isComputing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: DeviceType.isIpad ? 450 : 360)
        .frame(minWidth: 320, idealWidth: 360)
    }

    private var rangeSelection: Binding<Int> {
        Binding(
            get: { rangeYears },
            set: { newValue in
                rangeYears = newValue
                dataController.setRange(toYears: newValue)
            }
        )
    }

    private var rangeDescription: String {
        guard dataController.isReady else { return "" }
        let startYear = UTCDay.calendar.component(.year, from: dataController.startDate)
        let endYear = UTCDay.calendar.component(.year, from: dataController.endDate)
        return "±\(dataController.coveredYears) years (\(startYear)–\(endYear))"
    }
}
