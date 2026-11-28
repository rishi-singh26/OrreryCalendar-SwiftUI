//
//  InAppNotificationManager.swift
//  Orrery
//
//  Created by Rishi Singh on 16/10/26.
//

import SwiftUI
import Combine

// MARK: - Notification Manager
class InAppNotificationManager: ObservableObject {
    static let shared = InAppNotificationManager()
    
    @Published var notificationQueue: [InAppNotification] = []
    
    // MARK: Window targeting
    // The app can have several windows (macOS windows, iPad scenes), each with its own
    // overlay. A notification is shown in exactly one of them — the window the user was
    // last active in when it was posted — instead of being mirrored in all of them.
    private var registeredWindowIDs: [UUID] = []
    private var lastActiveWindowID: UUID?
    
    /// The window new notifications should appear in.
    private var targetWindowID: UUID? {
        lastActiveWindowID ?? registeredWindowIDs.first
    }
    
    private init() {}
    
    /// Called by a window's overlay when it attaches. Adopts notifications posted before
    /// any window was registered (e.g. during launch).
    func registerWindow(_ id: UUID) {
        guard !registeredWindowIDs.contains(id) else { return }
        registeredWindowIDs.append(id)
        for index in notificationQueue.indices where notificationQueue[index].windowID == nil {
            notificationQueue[index].windowID = id
        }
    }
    
    /// Called when a window's overlay goes away. Its notifications move to another window
    /// so they aren't orphaned (they stay unassigned if no window is left) — except action
    /// toasts, whose button acts on the window that's closing.
    func unregisterWindow(_ id: UUID) {
        registeredWindowIDs.removeAll { $0 == id }
        if lastActiveWindowID == id { lastActiveWindowID = nil }
        // Skip untouched mutations: even a no-op write to a @Published property publishes.
        guard notificationQueue.contains(where: { $0.windowID == id }) else { return }
        notificationQueue.removeAll { $0.mode == .actionToast && $0.windowID == id }
        let target = targetWindowID
        for index in notificationQueue.indices where notificationQueue[index].windowID == id {
            notificationQueue[index].windowID = target
        }
    }
    
    /// Marks `id` as the window the user is currently working in.
    func markWindowActive(_ id: UUID) {
        guard registeredWindowIDs.contains(id) else { return }
        lastActiveWindowID = id
    }
    
    // Show in-app notification
    func showNotification(
        title: String,
        message: String,
        type: NotificationType = .info,
        timing: NotificationTime = .medium,
        autoDismiss: Bool = false
    ) {
        let notification = InAppNotification(
            title: title,
            message: message,
            type: type,
            mode: .notification,
            timing: timing,
            autoDismiss: autoDismiss,
            windowID: targetWindowID
        )
        
        // Add to queue
        notificationQueue.append(notification)
    }
    
    func showToast(
        title: String,
        type: NotificationType = .info,
        timing: NotificationTime = .medium
    ) {
        let notification = InAppNotification(
            title: nil,
            message: title,
            type: type,
            mode: .toast,
            timing: timing,
            autoDismiss: true,
            windowID: targetWindowID
        )
        
        // Add to queue
        notificationQueue.append(notification)
    }
    
    /// Shows a toast with an action button. It stays until the user taps the button or
    /// dismisses it (by swiping, or with VoiceOver), or the caller removes it using the
    /// returned id.
    ///
    /// It appears in the window identified by `windowID` (see
    /// `EnvironmentValues.notificationWindowID`), as soon as that window has registered.
    /// Without an ID it goes to the last active window.
    /// Each window holds at most one: a new one replaces that window's previous one.
    @discardableResult
    func showActionToast(
        title: String,
        message: String? = nil,
        systemImage: String,
        actionTitle: String,
        in windowID: UUID?,
        action: @escaping @MainActor () -> Void
    ) -> UUID {
        let target = windowID ?? targetWindowID
        let notification = InAppNotification(
            title: title,
            message: message,
            type: .neutral,
            mode: .actionToast,
            windowID: target,
            systemImage: systemImage,
            action: NotificationAction(title: actionTitle, perform: action)
        )
        
        notificationQueue.removeAll { $0.mode == .actionToast && $0.windowID == target }
        notificationQueue.append(notification)
        return notification.id
    }
    
    // Clear all notifications (current and queued)
    func clearAllNotifications() {
        notificationQueue.removeAll()
    }
    
    // Get queue count for debugging/UI purposes
    var queueCount: Int {
        return notificationQueue.count
    }
    
    func removeNotification(_ id: UUID) {
        simpleRemoveNotification(id)
    }
    
    /// Distance (in points, including a velocity projection) an upward swipe must cover to dismiss.
    static let swipeDismissDistance: CGFloat = 50
    
    /// Updates the vertical swipe offset of the notification with `id`, if it's still queued.
    /// Negative values move the notification up.
    func setOffset(_ id: UUID, to offsetY: CGFloat) {
        guard let index = notificationQueue.firstIndex(where: { $0.id == id }) else { return }
        notificationQueue[index].offsetY = offsetY
    }
    
    func simpleRemoveNotification(_ id: UUID) {
        withAnimation(.bouncy) {
            notificationQueue.removeAll(where: { $0.id == id})
        }
    }
}

// MARK: - Notification Models
struct InAppNotification: Identifiable, Equatable {
    var id: UUID = UUID()
    let title: String?
    let message: String?
    let type: NotificationType
    let mode: NotificationMode
    // Timing
    var timing: NotificationTime = .medium
    /// When true the view removes the notification itself after `timing` elapses.
    var autoDismiss: Bool = false
    
    /// The window whose overlay shows this notification (see `InAppNotificationManager`).
    var windowID: UUID?
    
    /// Leading icon of an `.actionToast`.
    var systemImage: String?
    /// The button of an `.actionToast`.
    var action: NotificationAction?
    
    // View properties
    var offsetY: CGFloat = 0
}

enum NotificationMode {
    case notification
    case toast
    case actionToast
}

/// A button carried by a notification. Wraps the closure so that
/// `InAppNotification` can stay `Equatable`.
struct NotificationAction: Equatable {
    private let id = UUID()
    let title: String
    let perform: @MainActor () -> Void
    
    static func == (lhs: NotificationAction, rhs: NotificationAction) -> Bool {
        lhs.id == rhs.id
    }
}

enum NotificationTime: CGFloat {
    case short = 1.0
    case medium = 2.0
    case long = 3.5
    case extraLong = 5
}

enum NotificationType {
    case success
    case error
    case warning
    case info
    case neutral
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .neutral: return .clear
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "square"
        }
    }
}
