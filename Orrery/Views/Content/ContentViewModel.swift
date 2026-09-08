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

enum ControlPresentationState {
    case settings
    case savedItems
    case datePicker
    case none
}

@MainActor
@Observable
final class ContentViewModel {
    let rangeYearsForAnimatedScrubber = 10
    var selectedDate = UTCDay.todayAsUTCMidnight()
    var justSaved = false

    /// Single source of truth for which control surface `SmallScreenView` presents in its
    /// bottom control bar — that bar has one slot, so these are mutually exclusive by
    /// construction. `SmallScreenView`-only; do not read/write this from `LargeScreenView`,
    /// which uses the independent `show*` flags below instead since its popovers/inspector
    /// aren't confined to a single slot and can be presented independently of one another.
    var controlPresentationState: ControlPresentationState = .none

    /// Toggles `controlPresentationState`: switches to `state`, unless it's already showing,
    /// in which case it dismisses back to `.none`. `SmallScreenView`-only, mirroring the
    /// `Bool.toggle()` call sites used for `LargeScreenView`'s independent flags below.
    func toggleControlPresentation(_ state: ControlPresentationState) {
        controlPresentationState = controlPresentationState == state ? .none : state
    }

    /// Range the trailing-edge Moon-size scrubber's normalized (`0...1`) position
    /// maps onto — symmetric around the scrubber's default midpoint so a scrub of
    /// `0.5` reproduces `MoonPhaseRow`'s normal size (`1.0`) exactly; the low end
    /// scales the Moon discs down to 75%, the high end up to 125%. `SmallScreenView`-
    /// only, same scoping as `controlPresentationState` above.
    private let moonSizeMultiplierRange: ClosedRange<CGFloat> = 0.75...1.25

    /// Maps the Moon-size scrubber's persisted `0...1` position (kept in
    /// `SmallScreenView`, since it's `@AppStorage`-backed UI state) onto the size
    /// multiplier `MoonPhaseRow` reads.
    func moonSizeMultiplier(forScrub scrub: Double) -> CGFloat {
        let range = moonSizeMultiplierRange
        return range.lowerBound + CGFloat(scrub) * (range.upperBound - range.lowerBound)
    }

    /// Independent presentation flags for `LargeScreenView`'s toolbar popovers and inspector.
    /// Deliberately plain, unlinked `Bool`s (not derived from `controlPresentationState`)
    /// because that layout can show more than one of these surfaces at once — e.g. the saved
    /// list inspector staying open while the settings popover is also open. `LargeScreenView`-
    /// only; do not read/write these from `SmallScreenView`.
    var showSettings = false
    var showSavedList = false
    var showDatePicker = false

    private var hasInitializedSelection = false

    /// `startDate + 30 days` / `endDate - 30 days` — cached and recomputed only
    /// when the cached range itself changes (see `handleRangeChange`), since
    /// `isNearRangeEdge` is read every time `selectedDate` changes, including
    /// continuously while either scrub timeline is being dragged. Comparing
    /// `selectedDate` against these directly avoids two `Calendar`-based
    /// `UTCDay.dayCount` calls on every one of those checks. Default to distant
    /// past/future so `isNearRangeEdge` reads as "not near" before they're first
    /// seeded (in practice always seeded before `isReady` flips true — see
    /// `DataController.bootstrap`/`apply`, which set `startDate`/`endDate`,
    /// triggering `handleRangeChange`, before `isReady` is set).
    private var nearStartThreshold: Date = .distantPast
    private var nearEndThreshold: Date = .distantFuture

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

    /// Call from `.onChange(of: dataController.startDate)` / `.onChange(of: dataController.endDate)`.
    /// Re-clamps the selection whenever the cached range itself changes shape — needed
    /// because `DataController.setRange` (unlike `extendRange`, which only ever grows)
    /// can shrink the range out from under whatever's currently selected. Without this, a
    /// user viewing a date the new, smaller range no longer covers would be stuck looking
    /// at an uncomputed date forever, since nothing else re-triggers a computation for it.
    func handleRangeChange(dataController: DataController) {
        selectedDate = dataController.clampedDate(selectedDate)
        nearStartThreshold = UTCDay.calendar.date(byAdding: .day, value: 30, to: dataController.startDate) ?? .distantPast
        nearEndThreshold = UTCDay.calendar.date(byAdding: .day, value: -30, to: dataController.endDate) ?? .distantFuture
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
    /// either; this keeps compute triggers explicit/user-visible). Compares against
    /// `nearStartThreshold`/`nearEndThreshold` (kept in sync by `handleRangeChange`)
    /// rather than recomputing day counts with `Calendar` on every call.
    func isNearRangeEdge(dataController: DataController) -> Bool {
        guard dataController.isReady else { return false }
        return selectedDate < nearStartThreshold || selectedDate > nearEndThreshold
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
