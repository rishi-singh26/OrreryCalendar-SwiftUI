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
    @AppStorage(AppStorageKeys.hapticsEnabled) private var hapticsEnabled = true

    #if os(iOS)
    @State private var selectedAppIcon: AppIconOption = .current
    // @State private var currentIcon = UIApplication.shared.alternateIconName ?? Icon.primary.appIconName

    #endif

    #if DEBUG
    @State private var showNotificationTest = false
    #endif

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show Orbits", isOn: $showOrbits)
                Toggle("Show Labels", isOn: $showLabels)
                Toggle("Show Sun Halo", isOn: $showSunHalo)
            }
            .tint(.accentColor)
            
            Section {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            } footer: {
                Text("Vibration feedback when scrubbing dates and switching tabs.")
            }
            .tint(.accentColor)
            
            Section {
                Toggle(isOn: $syncPlanetDetailDate) {
                    Text("Sync Planet Detail Date")
                }
            } header: {
                Text("Planet Detail")
            } footer: {
                Text("Keep the date shown in the Planet Detail view matched with the main timeline. Turn off to browse a planet's dates on its own, without moving the main timeline.")
            }
            .tint(.accentColor)


            Section {
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
                            applyRange(toYears: rangeYears)
                        }
                        .disabled(dataController.isComputing)
                    }
                }
            } header: {
                Text("Date range")
            } footer: {
                Text("How far before and after today's date to cache planet positions for scrubbing. Larger ranges use more compute and storage.")
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

            #if DEBUG
            Section {
                Button("Notification Test") {
                    showNotificationTest = true
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Launch sample in-app notifications and toasts.")
            }
            #endif

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
        #if DEBUG
        .sheet(isPresented: $showNotificationTest) {
            NotificationTestView()
        }
        #endif
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

    /// Updates the cached range and, once that has finished successfully, tells the user.
    /// The wait runs in its own task rather than being tied to this view, so the
    /// notification still appears if Settings is dismissed while the range is computing.
    private func applyRange(toYears years: Int) {
        guard let task = dataController.setRange(toYears: years) else { return }
        let controller = dataController
        Task { @MainActor in
            await task.value
            // On failure Settings already shows the error (with Retry); don't announce success.
            guard controller.lastErrorMessage == nil else { return }
            InAppNotificationManager.shared.showNotification(
                title: "Date range updated",
                message: "Planet positions are now cached for ±\(years) years around today.",
                type: .info,
                timing: .extraLong,
                autoDismiss: true
            )
        }
    }

    private var rangeSelection: Binding<Int> {
        Binding(
            get: { rangeYears },
            set: { newValue in
                rangeYears = newValue
                applyRange(toYears: newValue)
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
