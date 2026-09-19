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
    @AppStorage(AppStorageKeys.boundaryTickFrequency) private var boundaryTickFrequency: BoundaryTickFrequency = .defaultFrequency
    @AppStorage(AppStorageKeys.syncPlanetDetailDate) private var syncPlanetDetailDate = true

    #if os(iOS)
    @State private var selectedAppIcon: AppIconOption = .current
    // @State private var currentIcon = UIApplication.shared.alternateIconName ?? Icon.primary.appIconName

    #endif

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show Orbits", isOn: $showOrbits)
                Toggle("Show Labels", isOn: $showLabels)
                Toggle("Show Sun Halo", isOn: $showSunHalo)
            }
            
            Section {
                Toggle(isOn: $syncPlanetDetailDate) {
                    Text("Sync Planet Detail Date")
                }
            } header: {
                Text("Planet Detail")
            } footer: {
                Text("Keep the date shown in the Planet Detail view matched with the main timeline. Turn off to browse a planet's dates on its own, without moving the main timeline.")
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
            
            Section("Scrubber") {
                Picker("Boundary Ticks", selection: $boundaryTickFrequency) {
                    ForEach(BoundaryTickFrequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                }
            }

            #if os(iOS)
            Section("App Icon") {
                HStack(spacing: 20) {
                    ForEach(AppIconOption.allCases) { option in
                        AppIconOptionButton(
                            option: option,
                            isSelected: selectedAppIcon == option
                        ) {
                            guard selectedAppIcon != option else { return }
                            // Only persist the selection once the OS confirms the icon
                            // actually changed — an optimistic write here would leave
                            // Settings showing the wrong icon as selected (and that
                            // option stuck, since the guard above would then skip it)
                            // if `setAlternateIconName` ever fails.
                            setIconSelection(to: option)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
            #endif
        }
        .formStyle(.grouped)
        .frame(minHeight: DeviceType.isIpad ? 450 : 360)
        .frame(minWidth: 320, idealWidth: 360)
        .scrollIndicators(.hidden)
    }

    #if os(iOS)
    private func setIconSelection(to newValue: AppIconOption) {
        let previous = selectedAppIcon
        selectedAppIcon = newValue
        newValue.apply { error in
            guard error != nil else { return }
            // The system couldn't apply the icon (e.g. simulator quirks); roll the picker back.
            selectedAppIcon = previous
        }
    }
    #endif

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
