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
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show orbits", isOn: $showOrbits)
                Toggle("Show labels", isOn: $showLabels)
                Toggle("Small moon", isOn: $smallMoon)
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
                        ZStack {
                            Image(systemName: "circle.lefthalf.filled")
                                .scaleEffect(1.2)
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(.background)
                                .scaleEffect(0.6)
                            Image(systemName: "circle.righthalf.filled")
                                .scaleEffect(0.6)
                        }
                    }

                }
            }

            Section("Date range") {
                if dataController.isReady {
                    Text("Currently cached: \(rangeDescription)")
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
                            .foregroundStyle(.red)
                        Button("Retry") {
                            dataController.extendRange(toYears: rangeYears)
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
                dataController.extendRange(toYears: newValue)
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

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            SettingsPanel()
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
