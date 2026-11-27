//
//  ExtendRangeToast.swift
//  Orrery
//
//  Posts the persistent "Extend date range" toast whenever `ExtendRangeButton` appears:
//  the selected date comes within 30 days of either end of a cached range that can still
//  grow. Shared by `SmallScreenView` and `LargeScreenView`.
//

import SwiftUI

private struct ExtendRangeToastModifier: ViewModifier {
    @Environment(DataController.self) private var dataController
    @Environment(\.notificationWindowID) private var windowID
    @State private var toastID: UUID?
    
    let viewModel: ContentViewModel
    let openSettings: @MainActor () -> Void
    
    /// Whether the toast this window posted is still up, i.e. hasn't been closed, swiped
    /// away.
    private var isToastQueued: Bool {
        InAppNotificationManager.shared.notificationQueue.contains { $0.id == toastID }
    }
    
    private var isPromptShown: Bool {
        viewModel.showsRangeExtensionPrompt(dataController: dataController)
    }
    
    func body(content: Content) -> some View {
        content
            // Fires only when the button appears, so a closed toast stays closed until the
            // button goes away and comes back. The button going away doesn't remove it, so
            // one that's still up is kept as is rather than replaced.
            .onChange(of: isPromptShown) { _, shown in
                guard shown, !isToastQueued else { return }
                toastID = InAppNotificationManager.shared.showActionToast(
                    title: "Extend date range",
                    message: "Near the cached date limit",
                    systemImage: "calendar.badge.plus",
                    actionTitle: "Settings",
                    in: windowID,
                    action: openSettings
                )
            }
            // Once a range change leaves nothing to suggest, so does the toast. Observes
            // the thresholds rather than the range itself, so they're never read before
            // they've caught up.
            .onChange(of: viewModel.nearStartThreshold) { dismissIfResolved() }
            .onChange(of: viewModel.nearEndThreshold) { dismissIfResolved() }
            // The settings action belongs to this window, so the toast goes with it.
            .onDisappear { dismiss() }
    }
    
    private func dismissIfResolved() {
        if !viewModel.canSuggestRangeExtension(dataController: dataController) { dismiss() }
    }
    
    private func dismiss() {
        guard let toastID else { return }
        InAppNotificationManager.shared.removeNotification(toastID)
        self.toastID = nil
    }
}

extension View {
    func extendRangeToast(viewModel: ContentViewModel, openSettings: @escaping @MainActor () -> Void) -> some View {
        modifier(ExtendRangeToastModifier(viewModel: viewModel, openSettings: openSettings))
    }
}
