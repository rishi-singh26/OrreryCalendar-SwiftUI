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
import OSLog

enum ControlPresentationState {
    case settings
    case savedItems
    case datePicker
    case planets
    case none
}

@MainActor
@Observable
final class ContentViewModel {
    var selectedDate = UTCDay.todayAsUTCMidnight()
    var justSaved = false
    @ObservationIgnored private var justSavedResetTask: Task<Void, Never>?
    
    let animation: Animation = .spring(duration: 0.3)
    let transition: AnyTransition = AnyTransition(.blurReplace)
    let reducedAnimation: Animation = .linear(duration: 0.1)
    let reducedTransition: AnyTransition = .opacity
    
    /// `animation`, softened when Reduce Motion is on — use at every call site that
    /// changes `controlPresentationState`.
    func effectiveAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reducedAnimation : animation
    }
    
    /// The overlay panels' open/close transition — `.blurReplace` normally, a plain
    /// fade when Reduce Motion is on to match `effectiveAnimation(reduceMotion:)`.
    func effectiveTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? reducedTransition : transition
    }
    
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
    
    /// Range the leading-edge Moon-size scrubber's normalized (`0...1`) position
    /// maps onto — symmetric around the scrubber's default midpoint so a scrub of
    /// `0.5` reproduces `MoonPhaseRow`'s normal size (`1.0`) exactly; the low end
    /// scales the Moon discs down to 75%, the high end up to 125%. Shared by
    /// `SmallScreenView` and `LargeScreenView`.
    private let moonSizeMultiplierRange: ClosedRange<CGFloat> = 0.75...1.25
    
    /// Maps the Moon-size scrubber's persisted `0...1` position (kept in
    /// each screen view, since it's `@AppStorage`-backed UI state) onto the size
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
    var showPlanetsView = false
    
    private var hasInitializedSelection = false
    
    /// Auto play engine. Idle (no task, no observation) unless the user starts it.
    let autoPlay = AutoPlayController()
    
    /// Starts/stops auto play, stepping `selectedDate` within the cached range.
    func toggleAutoPlay(dataController: DataController) {
        guard dataController.isReady || autoPlay.isPlaying else { return }
        autoPlay.onReachedEdge = { direction in
            InAppNotificationManager.shared.showNotification(
                title: "Information",
                message: "Auto Play stopped at the \(direction == .forward ? "end" : "start") of the cached date range",
                type: .neutral,
                timing: .long,
                autoDismiss: false
            )
        }
        autoPlay.toggle(
            currentDate: { [weak self] in self?.selectedDate ?? .distantPast },
            range: { dataController.startDate...dataController.endDate },
            apply: { [weak self] in self?.selectedDate = $0 }
        )
    }
    
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
    private(set) var nearStartThreshold: Date = .distantPast
    private(set) var nearEndThreshold: Date = .distantFuture
    
    /// Call from `.onChange(of: dataController.isReady)`. Seeds the initial selection once
    /// the controller has a cached range to clamp into, then resumes any range extension
    /// that was interrupted (e.g. app terminated mid-extension).
    func handleReadyChange(isReady: Bool, dataController: DataController, rangeYears: Int) {
        guard isReady else {
            autoPlay.stop()
            return
        }
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
                let newDate = dataController.clampedDate($0)
                // A scrub-timeline drag fights playback for control of the date, so it
                // always pauses auto play (see `AutoPlayManualChangeBehavior`).
                if self.autoPlay.isPlaying, newDate != self.selectedDate {
                    self.autoPlay.stop()
                }
                self.selectedDate = newDate
            }
        )
    }
    
    /// Bumped once for every *actual* change `setSelectedDateAnimated` makes to
    /// `selectedDate` — read by `OrreryView` (via its `dateChangeAnimationTrigger`
    /// parameter) to tell an explicit "jump to a date" apart from a `snapshot`
    /// change driven by continuous scrubbing, which should keep snapping straight
    /// to the new position exactly as before. Plain `Int` rather than a `Date`/`UUID`
    /// so equality is trivial and it survives `Observable` diffing cheaply.
    var dateChangeAnimationTrigger = 0
    
    /// Sets `selectedDate` to `newDate` (already clamped by the caller), bumping
    /// `dateChangeAnimationTrigger` iff it's an actual change — shared by every
    /// explicit "jump to a date" action (`animatedDateBinding`, `selectToday`) so
    /// they all animate consistently, and a no-op write (e.g. re-confirming the day
    /// already selected in a wheel `DatePicker`, or tapping "Today" while already
    /// there) never leaves a stray, unconsumed bump that could cause a later,
    /// unrelated scrub to be mistaken for one that should animate.
    private func setSelectedDateAnimated(_ newDate: Date) {
        guard newDate != selectedDate else { return }
        if autoPlay.isPlaying, AutoPlayManualChangeBehavior.persisted == .pause {
            autoPlay.stop()
        }
        selectedDate = newDate
        dateChangeAnimationTrigger += 1
    }
    
    /// Like `dateBinding`, but for date pickers: routes through
    /// `setSelectedDateAnimated` instead of writing `selectedDate` directly, so
    /// `OrreryView` eases the chart into the new positions instead of snapping.
    func animatedDateBinding(dataController: DataController) -> Binding<Date> {
        Binding(
            get: { self.selectedDate },
            set: { self.setSelectedDateAnimated(dataController.clampedDate($0)) }
        )
    }
    
    func selectToday(dataController: DataController) {
        setSelectedDateAnimated(dataController.clampedDate(dataController.todayDate))
    }
    
    /// Jumps `selectedDate` to `date` (clamped into the cached range), animating
    /// `OrreryView` into the new positions the same way `animatedDateBinding`/
    /// `selectToday` do. Used when a saved snapshot is picked from `SavedListView`,
    /// so that jump eases the chart instead of snapping it straight to the new date.
    func jumpToDate(_ date: Date, dataController: DataController) {
        setSelectedDateAnimated(dataController.clampedDate(date))
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
    
    /// Whether the cached range is worth extending from here: the selection is near an edge
    /// and the range isn't already as large as it gets.
    func canSuggestRangeExtension(dataController: DataController) -> Bool {
        isNearRangeEdge(dataController: dataController) && !dataController.isAtMaxRange
    }
    
    /// The single visibility rule for `ExtendRangeButton` and the "Extend date range" toast.
    /// Both are hidden while `SmallScreenView`'s Settings panel is up;
    /// `controlPresentationState` stays `.none` on large screens, so it has no effect there.
    func showsRangeExtensionPrompt(dataController: DataController) -> Bool {
        canSuggestRangeExtension(dataController: dataController) && controlPresentationState != .settings
    }
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Orrery", category: "Save")
    
    func save(dataController: DataController, modelContext: ModelContext) {
        guard let snapshot = dataController.snapshot(for: selectedDate) else { return }
        // CloudKit can't enforce unique constraints, so avoid creating a second entry for
        // a day that's already in the local store (including entries already synced from
        // other devices). Two devices saving the same day before either syncs can still
        // produce a duplicate; that's accepted.
        let day = snapshot.date
        let existing = FetchDescriptor<SavedSnapshot>(predicate: #Predicate { $0.date == day })
        let alreadySaved: Bool
        do {
            alreadySaved = try modelContext.fetchCount(existing) > 0
        } catch {
            // Can't tell — save anyway rather than lose the user's action; worst case is a duplicate.
            Self.logger.error("Duplicate check failed: \(error)")
            alreadySaved = false
        }
        if !alreadySaved {
            let saved = SavedSnapshot(date: snapshot.date, moonPhaseDeg: snapshot.moonPhaseDeg, planets: snapshot.planets)
            modelContext.insert(saved)
        }
        withAnimation {
            justSaved = true
        }
        justSavedResetTask?.cancel()
        justSavedResetTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation {
                justSaved = false
            }
        }
    }
}
