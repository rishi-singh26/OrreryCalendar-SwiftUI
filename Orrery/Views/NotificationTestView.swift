//
//  NotificationTestView.swift
//  Orrery
//
//  Test screen reached from Settings: buttons that launch the different in-app
//  notification and toast configurations. Presented as a sheet so it also verifies
//  that the notification overlay renders above modal presentations.
//

import SwiftUI

struct NotificationTestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = InAppNotificationManager.shared

    private let longMessage = "This is a much longer message used to check how the notification wraps across several lines and whether the dismiss button stays aligned."

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications (stay until dismissed)") {
                    ForEach(Self.types, id: \.name) { item in
                        Button("\(item.name) notification") {
                            manager.showNotification(title: item.name, message: "This is a \(item.name.lowercased()) notification.", type: item.type)
                        }
                    }
                    Button("Long message") {
                        manager.showNotification(title: "Long message", message: longMessage, type: .info)
                    }
                }

                Section("Notifications (auto-dismiss)") {
                    Button("Short (1s)") {
                        manager.showNotification(title: "Short", message: "Dismisses after 1 second.", type: .success, timing: .short, autoDismiss: true)
                    }
                    Button("Medium (2s)") {
                        manager.showNotification(title: "Medium", message: "Dismisses after 2 seconds.", type: .info, timing: .medium, autoDismiss: true)
                    }
                    Button("Long (3.5s)") {
                        manager.showNotification(title: "Long", message: "Dismisses after 3.5 seconds.", type: .warning, timing: .long, autoDismiss: true)
                    }
                }

                Section("Toasts") {
                    ForEach(Self.types, id: \.name) { item in
                        Button("\(item.name) toast") {
                            manager.showToast(title: "\(item.name) toast", type: item.type)
                        }
                    }
                    Button("Short toast (1s)") {
                        manager.showToast(title: "Short toast", type: .info, timing: .short)
                    }
                    Button("Long toast (3.5s)") {
                        manager.showToast(title: "Long toast", type: .info, timing: .long)
                    }
                    Button("Long message toast") {
                        manager.showToast(title: longMessage, type: .info)
                    }
                }

                Section("Stacking") {
                    Button("Mixed burst (4)") {
                        manager.showNotification(title: "One", message: "First of the burst.", type: .info, autoDismiss: true)
                        manager.showToast(title: "Two", type: .success)
                        manager.showNotification(title: "Three", message: "Third of the burst.", type: .warning, autoDismiss: true)
                        manager.showToast(title: "Four", type: .error)
                    }
                    Button("Notification after 3 seconds") {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            manager.showNotification(title: "Delayed", message: "Fired 3 seconds after tapping.", type: .info, autoDismiss: true)
                        }
                    }
                    Button("Clear all", role: .destructive) {
                        manager.clearAllNotifications()
                    }
                }

                Section {
                    LabeledContent("In queue", value: "\(manager.queueCount)")
                } footer: {
                    Text("Swipe a notification left to dismiss it. Notifications appear above this sheet.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Notification Test")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }

    private static let types: [(name: String, type: NotificationType)] = [
        ("Success", .success),
        ("Error", .error),
        ("Warning", .warning),
        ("Info", .info),
        ("Neutral", .neutral),
    ]
}

#Preview {
    NotificationTestView()
}
