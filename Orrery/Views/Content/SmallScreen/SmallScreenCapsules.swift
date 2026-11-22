//
//  SmallScreenCapsules.swift
//  Orrery
//

#if os (iOS)
import SwiftUI
import SwiftData

/// "Today" and "Choose a Date" buttons at the leading edge of `SmallScreenView`'s controls bar.
struct SmallScreenCalendarCapsule: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: ContentViewModel
    
    var body: some View {
        let isTodayButtonDisabled = !dataController.isReady || viewModel.isAlreadyOnToday(dataController: dataController)
        HStack(spacing: 20) {
            Button {
                viewModel.selectToday(dataController: dataController)
            } label: {
                Group {
                    if #available(iOS 26.0, *) {
                        Image(systemName: viewModel.todayCalendarSymbolName(dataController: dataController))
                    } else {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                .font(.title2)
            }
            .disabled(isTodayButtonDisabled)
            .help("Jump to Today")
            .accessibilityLabel("Today")
            .foregroundStyle(isTodayButtonDisabled ? .tertiary : .primary)
            
            Button {
                withAnimation(viewModel.effectiveAnimation(reduceMotion: reduceMotion)) {
                    viewModel.toggleControlPresentation(.datePicker)
                }
            } label: {
                Image(systemName: "calendar")
                    .font(.title2)
            }
            .disabled(!dataController.isReady)
            .help("Choose a Date")
            .accessibilityLabel("Choose Date")
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

/// Save, saved list, share and settings buttons at the trailing edge of `SmallScreenView`'s controls bar.
struct SmallScreenButtonsCapsule: View {
    @Environment(DataController.self) private var dataController
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.showLabels) private var showLabels = true
    @AppStorage(AppStorageKeys.showSunHalo) private var showSunHalo = true
    
    let viewModel: ContentViewModel
    let snapshot: DaySnapshot?
    let theme: ThemeColors
    let colorScheme: ColorScheme
    
    var body: some View {
        let animation = viewModel.effectiveAnimation(reduceMotion: reduceMotion)
        HStack(spacing: 20) {
            Button {
                viewModel.save(dataController: dataController, modelContext: modelContext)
            } label: {
                Image(systemName: viewModel.justSaved ? "checkmark" : "bookmark")
                    .font(.title2)
                    .foregroundStyle(viewModel.justSaved ? Color.accentColor : theme.ink)
            }
            .disabled(!dataController.isReady)
            .help(viewModel.justSaved ? "Saved" : "Save This View")
            .accessibilityLabel(viewModel.justSaved ? "Saved" : "Save")
            
            Button {
                withAnimation(animation) {
                    viewModel.toggleControlPresentation(.savedItems)
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
            .help("Show Saved Views")
            .accessibilityLabel("Saved Views")
            .foregroundStyle(.primary)
            
            Divider()
                .frame(height: 25)
            
            if let snapshot {
                PolaroidShareButton(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
                )
                .labelStyle(.iconOnly)
                .help("Share This View")
                .foregroundStyle(.primary)
            } else {
                Image(systemName: "square.and.arrow.up")
            }
            
            Button {
                withAnimation(animation) {
                    viewModel.toggleControlPresentation(.settings)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
            }
            .help("Settings")
            .accessibilityLabel("Settings")
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 11)
    }
}
#endif
