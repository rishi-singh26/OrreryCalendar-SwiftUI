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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        if notification.type != .neutral {
                            Image(systemName: notification.type.icon)
                                .foregroundColor(notification.type.color)
                                .font(.title3)
                        }
                        Text(notification.title ?? "")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Text(notification.message ?? "")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Button {
                    if let delayTask {
                        delayTask.cancel()
                    }
                    notificationManager.removeNotification(notification.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .glassOrSurface(in: .rect(cornerRadius: 18, style: .continuous))
        .contentShape(.rect(cornerRadius: 18))
        .padding(.horizontal, 10)
        .gesture(gesture)
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
    
    private var gesture: some Gesture {
        // Measure in the global space: the container moves this view (`.offset`) while it's
        // dragged, so in the default local space the gesture's own coordinates shift under
        // the finger on every update and the translation zigzags, making the drag flicker.
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                // Only follow upward drags; downward drags are ignored.
                let yOffset = value.translation.height < 0 ? value.translation.height : 0
                notificationManager.setOffset(notification.id, to: yOffset)
                cancelDelayTask()
            }.onEnded { value in
                let yOffset = value.translation.height + (value.velocity.height / 2)
                
                if -yOffset > InAppNotificationManager.swipeDismissDistance {
                    // Remove notification
                    notificationManager.removeNotification(notification.id)
                } else {
                    // Reset notification position
                    withAnimation(.snappy) {
                        notificationManager.setOffset(notification.id, to: 0)
                    }
                    createDelayTask()
                }
            }
    }
}

#Preview {
    InAppNotificationView(
        notification: .init(title: "Alert", message: "This is a notification", type: .info, mode: .toast),
    )
    .environmentObject(InAppNotificationManager.shared)
}
