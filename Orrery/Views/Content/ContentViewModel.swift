//
//  ContentViewModel.swift
//  Orrery
//
//  Shared state and behavior behind `SmallScreenView` and `LargeScreenView` (spec §5–§7):
//  date selection, range-edge detection, and the save-snapshot flow. `DataController` and
//  `modelContext` are read from the environment by the owning view, so they're passed into
//  the methods that need them rather than captured here.
//

import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class ContentViewModel {
    var selectedDate = UTCDay.todayAsUTCMidnight()
    var showSettings = false
    var showDatePicker = false
    var justSaved = false
    var showSavedList = false

    private var hasInitializedSelection = false

    /// Call from `.onChange(of: dataController.isReady)`. Seeds the initial selection once
    /// the controller has a cached range to clamp into, then resumes any range extension
    /// that was interrupted (e.g. app terminated mid-extension).
    func handleReadyChange(isReady: Bool, dataController: DataController, rangeYears: Int) {
        guard isReady else { return }
        if !hasInitializedSelection {
            selectedDate = dataController.clampedDate(dataController.todayDate)
            hasInitializedSelection = true
        }
        dataController.resumeRangeIfNeeded(desiredYears: rangeYears)
    }

    /// Binding that routes every write through `DataController.clampedDate`, so the scrub
    /// timeline and date pickers can never select a day outside the cached range.
    func dateBinding(dataController: DataController) -> Binding<Date> {
        Binding(
            get: { self.selectedDate },
            set: {
                self.selectedDate = dataController.clampedDate($0)
            }
        )
    }

    func selectToday(dataController: DataController) {
        selectedDate = dataController.clampedDate(dataController.todayDate)
    }

    func isAlreadyOnToday(dataController: DataController) -> Bool {
        UTCDay.midnight(of: selectedDate) == dataController.clampedDate(dataController.todayDate)
    }

    /// SF Symbol name for the "jump to today" toolbar button, e.g. "2.calendar" on the
    /// 2nd of the month — mirrors the day-of-month shown on the device's physical calendar.
    func todayCalendarSymbolName(dataController: DataController) -> String {
        let day = UTCDay.calendar.component(.day, from: dataController.todayDate)
        return "\(day).calendar"
    }

    /// Within 30 days of either edge of the cached range — a reasonable trigger to surface
    /// the "extend range" affordance rather than silently auto-extending (spec §5 allows
    /// either; this keeps compute triggers explicit/user-visible).
    func isNearRangeEdge(dataController: DataController) -> Bool {
        guard dataController.isReady else { return false }
        let toStart = (try? UTCDay.dayCount(from: dataController.startDate, to: selectedDate)) ?? .max
        let toEnd = (try? UTCDay.dayCount(from: selectedDate, to: dataController.endDate)) ?? .max
        return toStart < 30 || toEnd < 30
    }

    func save(dataController: DataController, modelContext: ModelContext) {
        guard let snapshot = dataController.snapshot(for: selectedDate) else { return }
        let saved = SavedSnapshot(date: snapshot.date, moonPhaseDeg: snapshot.moonPhaseDeg, planets: snapshot.planets)
        modelContext.insert(saved)
        withAnimation {
            justSaved = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation {
                justSaved = false
            }
        }
    }
}
