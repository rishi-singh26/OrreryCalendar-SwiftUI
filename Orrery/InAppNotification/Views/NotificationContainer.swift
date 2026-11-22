//
//  NotificationContainer.swift
//  Orrery
//
//  Created by Rishi Singh on 16/10/26.
//

import SwiftUI

struct NotificationContainer: View {
    @EnvironmentObject private var notificationManager:  InAppNotificationManager
    @State private var isExpanded: Bool = true
    
    /// The overlay window this container lives in; only that window's notifications render.
    let windowID: UUID
    
    /// This window's slice of the shared queue, in queue order.
    private var windowQueue: [InAppNotification] {
        notificationManager.notificationQueue.filter { $0.windowID == windowID }
    }
    
    /// Notifications are capped to a phone-like width on iPad and macOS, where the
    /// overlay spans a much wider window.
    private var maxContentWidth: CGFloat {
#if os(iOS)
        DeviceType.isIphone ? .infinity : 400
#else
        400
#endif
    }
    
    var body: some View {
        let queue = windowQueue
        ZStack(alignment: .top) {
            //let layout: AnyLayout = isExpanded ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(ZStackLayout())
            let layout: AnyLayout = AnyLayout(VStackLayout(spacing: 10))
            
            // Get the notifications in the correct order based on expansion state
            //let notifications = isExpanded ? notificationManager.notificationQueue.reversed() : notificationManager.notificationQueue
            let notifications = queue.reversed()
            
            layout {
                ForEach(Array(notifications.enumerated()), id: \.element.id) { enumIndex, notification in
                    // For ZStack (collapsed): use original index calculation for stacking effect
                    // For VStack (expanded): enumIndex is already correct (0 = top)
                    let stackIndex = isExpanded ? 0 : (notifications.count - 1 - enumIndex)
                    
                    // Calculate zIndex based on original queue position to maintain consistent layering
                    let originalIndex = queue.firstIndex(where: { $0.id == notification.id }) ?? 0
                    let baseZIndex = Double(queue.count - originalIndex)
                    
                    InAppNotificationSelector(notification: notification)
                        .offset(y: notification.offsetY)
                        .visualEffect { [isExpanded] content, proxy in
                            content
                                .scaleEffect(isExpanded ? 1 : scale(stackIndex), anchor: .top)
                                .offset(y: isExpanded ? 0 : offsetY(stackIndex))
                        }
                        .zIndex(1000 + baseZIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            //.onTapGesture {
            //    isExpanded.toggle()
            //}
        }
        .animation(.bouncy, value: isExpanded)
        // Keyed on the ids (not the whole `[InAppNotification]`) so per-frame swipe
        // offset updates don't get spring-animated and make dragging feel laggy.
        .animation(.spring(), value: queue.map(\.id))
        .onChange(of: queue.isEmpty) { oldValue, newValue in
            if newValue {
                isExpanded = true
            }
        }
        // Cap the content width on large screens, then center that capped block within
        // the full-window overlay.
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
#if os(macOS)
        .padding(.top, 8)
#endif
    }
    
    nonisolated func offsetY(_ index: Int) -> CGFloat {
        let offset = min(CGFloat(index) * 15, 30)
        return offset
    }
    
    nonisolated func scale(_ index: Int) -> CGFloat {
        let scale = min(CGFloat(index) * 0.1, 1)
        return 1 - scale
    }
}

fileprivate struct InAppNotificationSelector: View {
    let notification: InAppNotification
    
    var body: some View {
        Group {
            switch notification.mode {
            case .notification:
                InAppNotificationView(notification: notification)
            case .toast:
                InAppToastView(notification: notification)
            }
        }
    }
}
