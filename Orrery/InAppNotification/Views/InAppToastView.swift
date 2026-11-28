//
//  InAppToastView.swift
//  Orrery
//
//  Created by Rishi Singh on 16/10/26.
//

import SwiftUI

struct InAppToastView: View {
    @EnvironmentObject private var notificationManager:  InAppNotificationManager
    @State private var delayTask: DispatchWorkItem?
    
    let notification: InAppNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                if notification.type != .neutral {
                    Image(systemName: notification.type.icon)
                        .foregroundColor(notification.type.color)
                        .font(.title2)
                }
                
                Text(notification.message ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            // Stands in for the swipe, which VoiceOver users can't easily discover.
            .accessibilityAction(named: "Dismiss") {
                cancelDelayTask()
                notificationManager.removeNotification(notification.id)
            }
            .padding(10)
            .padding(.leading, notification.type == .neutral ? 10 : 0)
            .padding(.trailing, 10)
            .glassOrSurface(in: Capsule())
            .frame(maxWidth: .infinity)
        }
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
        InAppToastView(
            notification: .init(title: nil, message: "This is a toast with some long message. This message has to be long for test.", type: .info, mode: .toast, autoDismiss: false)
        )
        InAppToastView(
            notification: .init(title: nil, message: "This is a toast", type: .neutral, mode: .toast, autoDismiss: false)
        )
        InAppToastView(
            notification: .init(title: nil, message: "This is a toast", type: .info, mode: .toast, autoDismiss: false)
        )
    }
    .environmentObject(InAppNotificationManager.shared)
}
