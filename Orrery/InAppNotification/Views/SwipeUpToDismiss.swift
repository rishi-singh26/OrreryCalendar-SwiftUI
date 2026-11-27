//
//  SwipeUpToDismiss.swift
//  Orrery
//
//  The swipe-up-to-dismiss gesture shared by every in-app notification view.
//

import SwiftUI

private struct SwipeUpToDismissModifier: ViewModifier {
    @EnvironmentObject private var notificationManager: InAppNotificationManager
    
    let notificationID: UUID
    let onDrag: () -> Void
    let onSnapBack: () -> Void
    
    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
    
    private var gesture: some Gesture {
        // Measure in the global space: the container moves this view (`.offset`) while it's
        // dragged, so in the default local space the gesture's own coordinates shift under
        // the finger on every update and the translation zigzags, making the drag flicker.
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // Only follow upward drags; downward drags are ignored.
                let yOffset = value.translation.height < 0 ? value.translation.height : 0
                notificationManager.setOffset(notificationID, to: yOffset)
                onDrag()
            }.onEnded { value in
                let yOffset = value.translation.height + (value.velocity.height / 2)
                
                if -yOffset > InAppNotificationManager.swipeDismissDistance {
                    // Remove notification
                    notificationManager.removeNotification(notificationID)
                } else {
                    // Reset notification position
                    withAnimation(.snappy) {
                        notificationManager.setOffset(notificationID, to: 0)
                    }
                    onSnapBack()
                }
            }
    }
}

extension View {
    /// Lets the user swipe the notification with `id` upward to remove it. `onDrag` and
    /// `onSnapBack` let auto-dismissing views pause and restart their timer.
    func swipeUpToDismiss(
        _ id: UUID,
        onDrag: @escaping () -> Void = {},
        onSnapBack: @escaping () -> Void = {}
    ) -> some View {
        modifier(SwipeUpToDismissModifier(notificationID: id, onDrag: onDrag, onSnapBack: onSnapBack))
    }
}
