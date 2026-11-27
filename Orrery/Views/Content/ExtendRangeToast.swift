//
//  ExtendRangeToast.swift
//  Orrery
//
//  Posts the persistent "Extend date range" toast whenever `ExtendRangeButton` appears:
//  the selected date comes within 30 days of either end of the cached range. Shared by `SmallScreenView` and `LargeScreenView`.
//

import SwiftUI

private struct ExtendRangeToastModifier: ViewModifier {
    @Environment(DataController.self) private var dataController
    @State private var toastID: UUID?
    
    let viewModel: ContentViewModel
    /// True while the layout hides `ExtendRangeButton` even though the date is near an edge.
    let isSuppressed: Bool
    let openSettings: @MainActor () -> Void
    
    /// Whether the toast this window posted is still up, i.e. hasn't been closed, swiped
    /// away, or replaced by another window's.
    private var isToastQueued: Bool {
        InAppNotificationManager.shared.notificationQueue.contains { $0.id == toastID }
    }
    
    private var isNearEdge: Bool {
        viewModel.isNearRangeEdge(dataController: dataController)
    }
    
    /// Mirrors the condition under which the layout shows `ExtendRangeButton`.
    private var isButtonShown: Bool {
        isNearEdge && !isSuppressed
    }
    
    func body(content: Content) -> some View {
        content
            // Fires only when the button appears, so a closed toast stays closed until the
            // button goes away and comes back. The button going away doesn't remove it, so
            // one that's still up is kept as is rather than replaced.
            .onChange(of: isButtonShown) { _, shown in
                guard shown, !isToastQueued else { return }
                toastID = InAppNotificationManager.shared.showActionToast(
                    title: "Extend date range",
                    message: "No more cached dates",
                    onSettings: openSettings
                )
            }
            // Once the range has changed so the date is no longer near an end, the toast
            // has nothing left to say. Observes the thresholds rather than the range
            // itself, so `isNearEdge` is never read before they've caught up.
            .onChange(of: viewModel.nearStartThreshold) { dismissIfResolved() }
            .onChange(of: viewModel.nearEndThreshold) { dismissIfResolved() }
            // The settings action belongs to this window, so the toast goes with it.
            .onDisappear { dismiss() }
    }
    
    private func dismissIfResolved() {
        if !isNearEdge { dismiss() }
    }
    
    private func dismiss() {
        guard let toastID else { return }
        InAppNotificationManager.shared.removeNotification(toastID)
        self.toastID = nil
    }
}

extension View {
    func extendRangeToast(
        viewModel: ContentViewModel,
        isSuppressed: Bool = false,
        openSettings: @escaping @MainActor () -> Void
    ) -> some View {
        modifier(ExtendRangeToastModifier(viewModel: viewModel, isSuppressed: isSuppressed, openSettings: openSettings))
    }
}
