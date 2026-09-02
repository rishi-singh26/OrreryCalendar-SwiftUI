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
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false
    @AppStorage(AppStorageKeys.appearanceMode) private var appearanceMode: AppearanceMode = .system
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears

    private static let rangePresets = [5, 10, 15, 20, 50, 100]

    var body: some View {
        Form {
            Section {
                Toggle("Show orbits", isOn: $showOrbits)
                Toggle("Small moon", isOn: $smallMoon)
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
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

// MARK: - Adaptive presentation

extension View {
    /// Sheet on iPhone, popover on iPad/macOS, matching the floating-panel treatment
    /// from the web version. visionOS attaches it as a bottom ornament on the main
    /// window, per spec's stated preference — the content is always present and only
    /// `visibility` toggles, which is the standard visionOS pattern for an ornament
    /// that shows/hides.
    @ViewBuilder
    func orrerySettingsPresentation(isPresented: Binding<Bool>) -> some View {
        #if os(macOS)
        self.popover(isPresented: isPresented, arrowEdge: .bottom) {
            SettingsPanel().frame(width: 360, height: 420)
        }
        #elseif os(visionOS)
        self.ornament(
            visibility: isPresented.wrappedValue ? .visible : .hidden,
            attachmentAnchor: .scene(.bottom)
        ) {
            SettingsPanel()
                .frame(width: 360, height: 420)
        }
        #else
        self.modifier(AdaptiveSettingsPresentation(isPresented: isPresented))
        #endif
    }
}

#if os(iOS)
private struct AdaptiveSettingsPresentation: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content.popover(isPresented: $isPresented) {
                SettingsPanel().frame(width: 360, height: 420)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                SettingsPanel()
            }
        }
    }
}
#endif
