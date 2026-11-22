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
    @AppStorage(AppStorageKeys.showMoonSizeScrubber) private var showMoonSizeScrubber = true
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears
    @AppStorage(AppStorageKeys.boundaryTickFrequency) private var boundaryTickFrequency: BoundaryTickFrequency = .defaultFrequency
    @AppStorage(AppStorageKeys.syncPlanetDetailDate) private var syncPlanetDetailDate = true
    @AppStorage(AppStorageKeys.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppStorageKeys.autoPlayEnabled) private var autoPlayEnabled = true
    @AppStorage(AppStorageKeys.autoPlayRate) private var autoPlayRate: AutoPlayRate = AutoPlayRate.defaultRate
    @AppStorage(AppStorageKeys.autoPlayDirection) private var autoPlayDirection: AutoPlayDirection = AutoPlayDirection.defaultDirection
    @AppStorage(AppStorageKeys.autoPlayManualChange) private var autoPlayManualChange: AutoPlayManualChangeBehavior = AutoPlayManualChangeBehavior.defaultBehavior

#if os(iOS)
    @State private var showIconPicker: Bool = false
#endif

#if DEBUG
    @State private var showNotificationTest = false
#endif

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section("Display") {
                Toggle(isOn: $showOrbits) {
                    Label("Show Orbits", systemImage: "circle.circle")
                }
                Toggle(isOn: $showLabels) {
                    Label("Planet Labels", systemImage: "circle")
                }
                Toggle(isOn: $showSunHalo) {
                    Label("Sun Halo", systemImage: "sun.max.circle")
                }
                Toggle(isOn: $showMoonSizeScrubber) {
                    Label("Moon Size Control", systemImage: "moonphase.first.quarter")
                }
                Picker(selection: $appearanceMode) {
                    Label("System", systemImage: "iphone.gen2").tag(AppearanceMode.system)
                    Label("Light", systemImage: "sun.max").tag(AppearanceMode.light)
                    Label("Dark", systemImage: "moon.stars").tag(AppearanceMode.dark)
                } label: {
                    Label {
                        Text("Appearance")
                    } icon: {
                        AppearanceIconView(size: DeviceType.isMac ? 12 : 22, tint: DeviceType.isMac ? nil : .accentColor)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .tint(.accentColor)
            
            Section {
                Toggle(isOn: $autoPlayEnabled) {
                    Label("Enable Auto Play", systemImage: "play.fill")
                }
                
                if autoPlayEnabled {
                    Picker(selection: $autoPlayRate) {
                        ForEach(AutoPlayRate.allCases) { rate in
                            Text(rate.label).tag(rate)
                        }
                    } label: {
                        Label("Speed", systemImage: autoPlayRate.speedSystemName)
                    }
                    
                    Picker(selection: $autoPlayDirection) {
                        ForEach(AutoPlayDirection.allCases) { direction in
                            Text(direction.label).tag(direction)
                        }
                    } label: {
                        Label("Direction", systemImage: autoPlayDirection.systemImage)
                    }
                    
                    Picker(selection: $autoPlayManualChange) {
                        ForEach(AutoPlayManualChangeBehavior.allCases) { behavior in
                            Text(behavior.label).tag(behavior)
                        }
                    } label: {
                        Label("When I change the date", systemImage: "calendar")
                    }
                }
            } header: {
                Text("Auto Play")
            } footer: {
                Text("Shows a Play button that moves the date automatically. Dragging the timeline always pauses; the last option applies to the date picker, Today and saved views. Playback stops at the end of the cached range.")
            }
            .tint(.accentColor)
            
            Section {
                Picker(selection: $boundaryTickFrequency) {
                    ForEach(BoundaryTickFrequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                } label: {
                    Label("Boundary Ticks", systemImage: "lines.measurement.horizontal.aligned.bottom")
                }
                
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptic Feedback", systemImage: "lightspectrum.horizontal")
                }
            } header: {
                Text("Scrubber")
            } footer: {
                Text("Vibration feedback when scrubbing dates and switching tabs.")
            }
            .tint(.accentColor)
            
            Section {
                Toggle(isOn: $syncPlanetDetailDate) {
                    Label("Sync Planet Detail Date", systemImage: "calendar.circle")
                }
            } header: {
                Text("Planet Detail")
            } footer: {
                Text("Keep the date shown in the Planet Detail panel synced with the main timeline on the home page. Turn off to browse a planet's dates on its own, without moving the main timeline.")
            }
            .tint(.accentColor)
            
            
            Section {
                if dataController.isReady {
                    Text("Cached: \(rangeDescription)")
                        .foregroundStyle(.secondary)
                }
                
                Picker(selection: rangeSelection) {
                    ForEach(Self.rangePresets, id: \.self) { years in
                        Text("±\(years) years").tag(years)
                    }
                } label: {
                    Label("Extend range", systemImage: "minus.plus.lines.measurement.horizontal.aligned.bottom")
                }
                .disabled(dataController.isComputing)
                
                if dataController.isComputing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.regular)
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
            
#if os(iOS)
            Section("App Icon") {
                Button {
                    showIconPicker.toggle()
                } label: {
                    HStack {
                        Label {
                            Text("Change App Icon")
                        } icon: {
                            Image(systemName: "app.badge.checkmark")
                                .foregroundStyle(.accent)
                        }
                        
                        Spacer()
                        Image(AppIcon.current.previewImageName)
                            .resizable()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: 1)
                            )
                    }
                }
                .foregroundStyle(.primary)
                .appIconPicker(isPresented: $showIconPicker)
            }
#endif
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
            
        }
        .formStyle(.grouped)
        .frame(minHeight: DeviceType.isIpad ? 450 : 360)
        .frame(minWidth: 350, idealWidth: 400)
        .scrollIndicators(.hidden)
#if DEBUG
        .sheet(isPresented: $showNotificationTest) {
            NotificationTestView()
        }
#endif
    }

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
