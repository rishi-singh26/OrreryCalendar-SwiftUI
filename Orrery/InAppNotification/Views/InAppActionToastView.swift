//
//  InAppActionToastView.swift
//  Orrery
//
//  A persistent banner-style toast, modeled on the iOS system banner (e.g. iPhone
//  Mirroring): icon, title and subtitle, then a "Settings" pill and a close button.
//  It never auto-dismisses; it can be closed with the ✕ button or swiped up.
//

import SwiftUI

struct InAppActionToastView: View {
    @EnvironmentObject private var notificationManager: InAppNotificationManager
    
    let notification: InAppNotification
    
    private let buttonHeight: CGFloat = 40
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.title3)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(notification.title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if let message = notification.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            
            Button {
                notification.settingsAction?.perform()
                notificationManager.removeNotification(notification.id)
            } label: {
                Text("Settings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .frame(height: buttonHeight)
                    .background(Color.primary.opacity(0.08), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 18)
        .padding([.vertical, .trailing], 8)
        .glassOrSurface(in: Capsule())
        .contentShape(.capsule)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .gesture(gesture)
    }
    
    private var gesture: some Gesture {
        // Global space for the same reason as in `InAppToastView`: the container moves this
        // view while it's dragged, which would make local coordinates flicker.
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // Only follow upward drags; downward drags are ignored.
                let yOffset = value.translation.height < 0 ? value.translation.height : 0
                notificationManager.setOffset(notification.id, to: yOffset)
            }.onEnded { value in
                let yOffset = value.translation.height + (value.velocity.height / 2)
                
                if -yOffset > InAppNotificationManager.swipeDismissDistance {
                    notificationManager.removeNotification(notification.id)
                } else {
                    withAnimation(.snappy) {
                        notificationManager.setOffset(notification.id, to: 0)
                    }
                }
            }
    }
}

#Preview {
    InAppActionToastView(
        notification: .init(title: "Extend date range", message: "No more cached dates", type: .neutral, mode: .actionToast)
    )
    .environmentObject(InAppNotificationManager.shared)
}
