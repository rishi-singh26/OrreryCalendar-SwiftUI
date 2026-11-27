//
//  InAppActionToastView.swift
//  Orrery
//
//  A persistent banner-style toast, modeled on the iOS system banner (e.g. iPhone
//  Mirroring): icon, title and subtitle, then an action pill and a close button.
//  It never auto-dismisses; it can be closed with the ✕ button or swiped up.
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
                
                if let message = notification.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(2)
            .accessibilityElement(children: .combine)
            
            HStack(spacing: 6) {
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
                
                Button {
                    notificationManager.removeNotification(notification.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: buttonHeight, height: buttonHeight)
                        .background(Color.primary.opacity(0.08), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
            }
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
