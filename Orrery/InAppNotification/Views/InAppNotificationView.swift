//
//  InAppNotificationView.swift
//  Orrery
//
//  Created by Rishi Singh on 16/10/26.
//

import SwiftUI

struct InAppNotificationView: View {
    @EnvironmentObject private var notificationManager:  InAppNotificationManager
    @State private var delayTask: DispatchWorkItem?
    
    let notification: InAppNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                if notification.type != .neutral {
                    Image(systemName: notification.type.icon)
                        .foregroundColor(.white)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(notification.type.color)
                        .contentShape(.rect(cornerRadius: 10))
                        .clipShape(.rect(cornerRadius: 10))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title = notification.title {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let message = notification.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(notification.title == nil ? nil : .secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
            // Stands in for the swipe, which VoiceOver users can't easily discover.
            .accessibilityAction(named: "Dismiss") {
                cancelDelayTask()
                notificationManager.removeNotification(notification.id)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .glassOrSurface(in: .rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect(cornerRadius: 20))
        .padding(.horizontal, 10)
        .swipeUpToDismiss(notification.id, onDrag: cancelDelayTask, onSnapBack: createDelayTask)
        .onAppear(perform: createDelayTask)
    }
    
    private func createDelayTask() {
        guard notification.autoDismiss else { return }
        guard delayTask == nil else { return }
        delayTask = .init(block: {
            notificationManager.simpleRemoveNotification(notification.id)
        })
        
        if let delayTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.timing.rawValue, execute: delayTask)
        }
    }
    
    private func cancelDelayTask() {
        if let delayTask {
            delayTask.cancel()
            self.delayTask = nil
        }
    }
}

#Preview {
    Group {
        InAppNotificationView(
            notification: .init(title: "Alert", message: "This is a test notification. This notification has some long content. This needs to be long for proper testing.", type: .info, mode: .toast),
        )
        InAppNotificationView(
            notification: .init(title: "Error", message: "This is a test notification. This notification has some long content.", type: .error, mode: .notification),
        )
        InAppNotificationView(
            notification: .init(title: "Success", message: "This is a test notification", type: .success, mode: .toast),
        )
        InAppNotificationView(
            notification: .init(title: nil, message: "This is a test notification.\nThis notification has some long content.", type: .neutral, mode: .toast),
        )
        InAppNotificationView(
            notification: .init(title: nil, message: "This is a test notification.\nThis notification has some long content.", type: .success, mode: .toast),
        )
    }
    .environmentObject(InAppNotificationManager.shared)
}
