//
//  LargeScreenToolbar.swift
//  Orrery
//

import SwiftUI
import SwiftData

/// `LargeScreenView`'s toolbar. Everything it needs is passed in explicitly rather than read
/// from the environment, since `ToolbarContent` isn't a `View`.
struct LargeScreenToolbar: ToolbarContent {
    @Bindable var viewModel: ContentViewModel
    let dataController: DataController
    let modelContext: ModelContext
    let snapshot: DaySnapshot?
    let theme: ThemeColors
    let colorScheme: ColorScheme
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let autoPlayEnabled: Bool
    /// `viewModel.effectiveAnimation(reduceMotion:)`, resolved by the caller.
    let animation: Animation
    let toggleSettings: () -> Void
    
    /// Play/Pause for Auto Play. Its settings live in the main Settings panel.
    private var autoPlayButton: some View {
        let isPlaying = viewModel.autoPlay.isPlaying
        
        return Button {
            withAnimation(animation) {
                viewModel.toggleAutoPlay(dataController: dataController)
            }
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(!dataController.isReady)
        .help(isPlaying ? "Pause Auto Play" : "Start Auto Play")
        .accessibilityLabel("Auto play")
        .accessibilityValue(isPlaying ? "Playing" : "Paused")
    }
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if #available(iOS 26.0, macOS 26.0, *) {
                Button {
                    withAnimation(animation) {
                        viewModel.showPlanetsView.toggle()
                    }
                } label: {
                    Text("Planets")
                        .font(.caption)
                        .monospaced()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button {
                    withAnimation(animation) {
                        viewModel.showPlanetsView.toggle()
                    }
                } label: {
                    Text("Planets")
                        .font(.caption)
                        .monospaced()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            
            if autoPlayEnabled {
                autoPlayButton
            }
            
            Button {
                viewModel.selectToday(dataController: dataController)
            } label: {
                if #available(iOS 26.0, macOS 26.0, *) {
                    Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
                } else {
                    Image(systemName: "calendar.badge.clock")
                }
            }
            .disabled(!dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController))
            .help("Jump to Today")
            .accessibilityLabel("Today")
            
            
            Button {
                viewModel.showDatePicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .disabled(!dataController.isReady)
            .help("Choose a Date")
            .accessibilityLabel("Choose Date")
            .popover(isPresented: $viewModel.showDatePicker) {
                DatePickerPopoverContent(viewModel: viewModel, dataController: dataController, theme: theme)
            }
            
            
            Button {
                viewModel.save(dataController: dataController, modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                    .foregroundStyle(viewModel.justSaved ? theme.brass : theme.ink)
            }
            .disabled(!dataController.isReady)
            .help(viewModel.justSaved ? "Saved" : "Save This View")
            .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
            
            if DeviceType.isIpad {
                Button {
                    viewModel.showSavedList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Show Saved Views")
                .accessibilityLabel("Saved Views")
                .popover(isPresented: $viewModel.showSavedList) {
                    SavedListView { date in
                        viewModel.jumpToDate(date, dataController: dataController)
                    }
                    .frame(minHeight: DeviceType.isIpad ? 450 : 360)
                    .frame(minWidth: 320, idealWidth: 360)
                }
            } else {
                Button {
                    viewModel.showSavedList.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Show Saved Views")
                .accessibilityLabel("Saved Views")
            }
            
            if let snapshot {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
            }
            
            Button {
                toggleSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .help("Settings")
            .accessibilityLabel("Settings")
            .popover(isPresented: $viewModel.showSettings) {
                SettingsPanel()
            }
        }
    }
}

/// Contents of the toolbar's "Choose a Date" popover — a month/year selector plus calendar on
/// macOS, the graphical `DatePicker` on iPad.
private struct DatePickerPopoverContent: View {
    let viewModel: ContentViewModel
    let dataController: DataController
    let theme: ThemeColors
    
    var body: some View {
        VStack(spacing: 8) {
#if os (macOS)
            MonthYearSelector(
                selection: viewModel.animatedDateBinding(dataController: dataController),
                minDate: dataController.startDate,
                maxDate: dataController.endDate
            )
            
            MacCalendarView(
                selection: viewModel.animatedDateBinding(dataController: dataController),
                minDate: dataController.startDate,
                maxDate: dataController.endDate,
                today: dataController.todayDate,
                theme: theme
            )
#else
            DatePicker(
                "Date",
                selection: viewModel.animatedDateBinding(dataController: dataController),
                in: dataController.startDate...dataController.endDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
#endif
        }
        .padding()
        .frame(minWidth: DeviceType.isIpad ? 320 : nil, minHeight: DeviceType.isIpad ? 320 : nil)
    }
}
