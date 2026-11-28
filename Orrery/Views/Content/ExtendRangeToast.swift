//
//  ExtendRangeToast.swift
//  Orrery
//
//  Shows the "Extend date range" toast along with `ExtendRangeButton`: when the selected
//  date comes within 30 days of either end of a cached range that can still grow. Shared
//  by `SmallScreenView` and `LargeScreenView`.
//

import SwiftUI

/// Decides when the toast is posted and removed, apart from the view so it can be tested.
struct ExtendRangeToastPresenter {
    static let title = "Extend date range"
    static let message = "Near the cached date limit"
    
    private(set) var toastID: UUID?
    
    private var manager: InAppNotificationManager { .shared }
    
    /// Whether the toast this window posted is still up, i.e. hasn't been closed or swiped
    /// away.
    private var isToastQueued: Bool {
        manager.notificationQueue.contains { $0.id == toastID }
    }
    
    /// Posts on the prompt appearing, keeping a toast that's still up. The prompt merely
    /// being hidden (by the Settings panel) doesn't remove it.
    mutating func promptChanged(isShown: Bool, windowID: UUID?, openSettings: @escaping @MainActor () -> Void) {
        guard isShown, !isToastQueued else { return }
        toastID = manager.showActionToast(
            title: Self.title,
            message: Self.message,
            systemImage: "calendar.badge.plus",
            actionTitle: "Settings",
            in: windowID,
            action: openSettings
        )
        // The overlay is a separate window, so VoiceOver wouldn't otherwise mention it.
        AccessibilityNotification.Announcement("\(Self.title). \(Self.message)").post()
    }
    
    /// Removes the toast once there's nothing left to suggest: the date moved away from
    /// the edge, or the range changed.
    mutating func suggestionChanged(canSuggest: Bool) {
        if !canSuggest { dismiss() }
    }
    
    mutating func dismiss() {
        guard let toastID else { return }
        manager.removeNotification(toastID)
        self.toastID = nil
    }
}

private struct ExtendRangeToastModifier: ViewModifier {
    @Environment(DataController.self) private var dataController
    @Environment(\.notificationWindowID) private var windowID
    @State private var presenter = ExtendRangeToastPresenter()
    
    let viewModel: ContentViewModel
    let openSettings: @MainActor () -> Void
    
    private var canSuggest: Bool {
        viewModel.canSuggestRangeExtension(dataController: dataController)
    }
    
    private var isPromptShown: Bool {
        viewModel.showsRangeExtensionPrompt(dataController: dataController)
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPromptShown) { _, shown in
                presenter.promptChanged(isShown: shown, windowID: windowID, openSettings: openSettings)
            }
            .onChange(of: canSuggest) { _, canSuggest in
                presenter.suggestionChanged(canSuggest: canSuggest)
            }
            // The settings action belongs to this window, so the toast goes with it.
            .onDisappear { presenter.dismiss() }
    }
}

extension View {
    func extendRangeToast(viewModel: ContentViewModel, openSettings: @escaping @MainActor () -> Void) -> some View {
        modifier(ExtendRangeToastModifier(viewModel: viewModel, openSettings: openSettings))
    }
}
