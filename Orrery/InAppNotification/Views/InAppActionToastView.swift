//
//  InAppActionToastView.swift
//  Orrery
//
//  A persistent banner-style toast, modeled on the iOS system banner (e.g. iPhone
//  Mirroring): icon, title and subtitle, then an action pill. It has no timer and
//  no close button: it's swiped up to dismiss, or dismissed with VoiceOver's actions.
//

import SwiftUI

struct InAppActionToastView: View {
    @EnvironmentObject private var notificationManager: InAppNotificationManager
    
    let notification: InAppNotification
    
    private let buttonHeight: CGFloat = 40
    
    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = notification.systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                Text(notification.title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let message = notification.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            // Stands in for the swipe, which VoiceOver users can't easily discover.
            .accessibilityAction(named: "Dismiss") {
                notificationManager.removeNotification(notification.id)
            }
            
            Button {
                notification.action?.perform()
                notificationManager.removeNotification(notification.id)
            } label: {
                Text(notification.action?.title ?? "")
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
        .swipeUpToDismiss(notification.id)
    }
}

#Preview {
    InAppActionToastView(
        notification: .init(
            title: "Extend date range", message: "Near the cached date limit",
            type: .neutral, mode: .actionToast, systemImage: "calendar.badge.plus",
            action: .init(title: "Settings", perform: {})
        )
    )
    .environmentObject(InAppNotificationManager.shared)
}
