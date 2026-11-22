//
//  InAppNotificationOverlay.swift
//  Orrery
//
//  Created by Rishi Singh on 16/10/26.
//
//  Renders `InAppNotificationManager`'s queue in its own window stacked above the host
//  window, so notifications stay visible above `.sheet()`/popover content. A ZStack inside
//  the host's view tree can't do that — a sheet presents above the whole host hierarchy.
//  iOS uses one `UIWindow` per `UIWindowScene`; macOS uses one child `NSWindow` per host
//  `NSWindow`. Both resolve the window backing *this* view (never "the first scene"), so
//  several iPad scenes / macOS windows each get their own correctly-attached overlay.
//

import SwiftUI

extension View {
    /// Apply once, near the root of each window's content (the view given to `WindowGroup`).
    /// All windows mirror `InAppNotificationManager.shared`'s queue.
    func inAppNotificationOverlay() -> some View {
        modifier(InAppNotificationOverlayModifier())
    }
}

#if os(iOS)
import UIKit

private struct InAppNotificationOverlayModifier: ViewModifier {
    @State private var controller = OverlayWindowController()
    
    func body(content: Content) -> some View {
        content.background(
            WindowSceneFinder { scene in
                controller.attach(to: scene)
            }
        )
    }
}

/// Resolves the `UIWindowScene` hosting this view once UIKit places it in a window.
private struct WindowSceneFinder: UIViewRepresentable {
    var onResolve: (UIWindowScene) -> Void
    
    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        view.onResolve = onResolve
        return view
    }
    
    func updateUIView(_ uiView: FinderView, context: Context) {
        uiView.onResolve = onResolve
        if let scene = uiView.window?.windowScene {
            onResolve(scene)
        }
    }
    
    final class FinderView: UIView {
        var onResolve: ((UIWindowScene) -> Void)?
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene {
                onResolve?(scene)
            }
        }
    }
}

@MainActor
private final class OverlayWindowController {
    private var overlayWindow: PassthroughWindow?
    private weak var attachedScene: UIWindowScene?
    private var disconnectObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    /// Identifies this scene's overlay in `InAppNotificationManager`, which routes each
    /// notification to a single window.
    private let windowID = UUID()
    
    func attach(to scene: UIWindowScene) {
        // Already attached to this scene (body re-evaluated): nothing to do.
        guard attachedScene !== scene || overlayWindow == nil else { return }
        detach()
        attachedScene = scene
        
        let manager = InAppNotificationManager.shared
        manager.registerWindow(windowID)
        if scene.activationState == .foregroundActive {
            manager.markWindowActive(windowID)
        }
        
        let window = PassthroughWindow(windowScene: scene)
        window.backgroundColor = .clear
        // Any touch in this scene reaches the overlay's hit test first, so it doubles as a
        // reliable "the user is working in this scene" signal (e.g. tapping between iPad
        // Split View / Stage Manager windows that are all foreground-active).
        let windowID = windowID
        window.onTouch = { manager.markWindowActive(windowID) }
        let hosting = UIHostingController(
            rootView: NotificationContainer(windowID: windowID)
                .environmentObject(InAppNotificationManager.shared)
        )
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting
        window.isHidden = false
        window.isUserInteractionEnabled = true
        overlayWindow = window
        
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didDisconnectNotification,
            object: scene,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.detach() }
        }
        activateObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: scene,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                InAppNotificationManager.shared.markWindowActive(self.windowID)
            }
        }
    }
    
    func detach() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        attachedScene = nil
        InAppNotificationManager.shared.unregisterWindow(windowID)
        for observer in [disconnectObserver, activateObserver] {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
        disconnectObserver = nil
        activateObserver = nil
    }
}

/// Transparent, scene-filling window that only claims touches that land on notification content.
private final class PassthroughWindow: UIWindow {
    /// Called whenever a touch is hit-tested in this window's scene.
    var onTouch: (() -> Void)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if event?.type == .touches { onTouch?() }
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else { return nil }
        
        if #available(iOS 26.0, *) {
            // On iOS 26 the SwiftUI hierarchy is opaque to UIKit: the hosting view no
            // longer exposes its content as hit-testable subviews, so the subview walk
            // below finds nothing. Decide pass-through from CALayer hit testing instead:
            // a hit on the hosting view's own layer means the touch landed on empty area.
            let hitLayer = rootView.layer.hitTest(point)
            return (hitLayer == nil || hitLayer === rootView.layer) ? nil : hitView
        } else {
            // iOS 18: check each subview in the overlay from front to back. A hit means
            // the touch landed on notification content, but return the hosting view
            // itself rather than the inner subview that was hit. Returning SwiftUI's
            // internal `_UIGraphicsView`/`CGDrawingView` routes the touch correctly but
            // SwiftUI never acts on it, leaving buttons and drag gestures dead on iOS 18.
            for subview in rootView.subviews.reversed() {
                let pointInSubview = subview.convert(point, from: rootView)
                if subview.hitTest(pointInSubview, with: event) != nil {
                    return rootView
                }
            }
            return nil
        }
    }
}
#endif

#if os(macOS)
import AppKit

private struct InAppNotificationOverlayModifier: ViewModifier {
    @State private var controller = OverlayWindowController()
    
    func body(content: Content) -> some View {
        content.background(
            WindowFinder { window in
                controller.attach(to: window)
            }
        )
    }
}

/// Resolves the `NSWindow` hosting this view once AppKit places it in a window.
private struct WindowFinder: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> FinderView {
        let view = FinderView()
        view.onResolve = onResolve
        return view
    }
    
    func updateNSView(_ nsView: FinderView, context: Context) {
        nsView.onResolve = onResolve
        if let window = nsView.window {
            onResolve(window)
        }
    }
    
    final class FinderView: NSView {
        var onResolve: ((NSWindow) -> Void)?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                onResolve?(window)
            }
        }
    }
}

@MainActor
private final class OverlayWindowController {
    private weak var hostWindow: NSWindow?
    private var panel: OverlayPanel?
    private var observers: [NSObjectProtocol] = []
    private var layoutObservation: NSKeyValueObservation?
    /// Identifies this window's overlay in `InAppNotificationManager`, which routes each
    /// notification to a single window.
    private let windowID = UUID()
    
    func attach(to window: NSWindow) {
        // Already attached to this window (body re-evaluated): nothing to do.
        guard hostWindow !== window || panel == nil else { return }
        detach()
        hostWindow = window
        
        let manager = InAppNotificationManager.shared
        manager.registerWindow(windowID)
        if window.isKeyWindow {
            manager.markWindowActive(windowID)
        }
        
        let newPanel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.isReleasedWhenClosed = false
        // Click-through is decided per-pixel: OverlayPanel forwards events that miss the
        // notification content to the host window (see OverlayPanel.sendEvent).
        newPanel.ignoresMouseEvents = false
        newPanel.acceptsMouseMovedEvents = true
        newPanel.contentView = PassthroughHostingView(
            rootView: NotificationContainer(windowID: windowID)
                .environmentObject(InAppNotificationManager.shared)
        )
        panel = newPanel
        
        window.addChildWindow(newPanel, ordered: .above)
        syncFrame()
        
        // The toolbar can appear or change height without the window being resized.
        layoutObservation = window.observe(\.contentLayoutRect) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.syncFrame() }
        }
        
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncFrame() }
            },
            center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncFrame() }
            },
            center.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncFrame() }
            },
            center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.detach() }
            },
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    InAppNotificationManager.shared.markWindowActive(self.windowID)
                }
            },
        ]
    }
    
    /// Child windows don't reliably track their parent's size, so re-derive the panel's
    /// frame from the host window's content layout area (excluding the title bar and
    /// toolbar) on every resize/move/screen change, and when that area itself changes.
    private func syncFrame() {
        guard let hostWindow, let panel else { return }
        // `contentLayoutRect` is the content area *below* the title bar and toolbar, so
        // notifications sit under them instead of covering them.
        panel.setFrame(hostWindow.convertToScreen(hostWindow.contentLayoutRect), display: true)
    }
    
    func detach() {
        if let hostWindow, let panel {
            hostWindow.removeChildWindow(panel)
        }
        panel?.close()
        panel = nil
        hostWindow = nil
        InAppNotificationManager.shared.unregisterWindow(windowID)
        layoutObservation = nil
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }
}

/// Borderless overlay that never takes key/main status from the host window, and hands any
/// mouse/scroll event that doesn't land on notification content to its parent window.
/// Returning `nil` from `hitTest` alone isn't enough: a window still *receives* the event the
/// window server routed to it, so without forwarding the transparent overlay would swallow
/// every click meant for the host window.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    /// True between a mouse-down that missed the content and the matching mouse-up, so the
    /// drag/up events of that gesture are also forwarded to the host.
    private var forwardingGesture = false
    
    private func hitsContent(_ event: NSEvent) -> Bool {
        guard let contentView, let container = contentView.superview else { return false }
        return contentView.hitTest(container.convert(event.locationInWindow, from: nil)) != nil
    }
    
    override func sendEvent(_ event: NSEvent) {
        guard let parent else {
            super.sendEvent(event)
            return
        }
        let forward: Bool
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            forwardingGesture = !hitsContent(event)
            forward = forwardingGesture
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            forward = forwardingGesture
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            forward = forwardingGesture
            forwardingGesture = false
        case .mouseMoved, .scrollWheel:
            forward = !hitsContent(event)
        default:
            forward = false
        }
        guard forward, let forwarded = translated(event, to: parent) else {
            super.sendEvent(event)
            return
        }
        parent.sendEvent(forwarded)
    }
    
    private func translated(_ event: NSEvent, to parent: NSWindow) -> NSEvent? {
        if event.type == .scrollWheel {
            guard let cgEvent = event.cgEvent?.copy() else { return nil }
            let number = Int64(parent.windowNumber)
            cgEvent.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: number)
            cgEvent.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: number)
            return NSEvent(cgEvent: cgEvent)
        }
        let screenPoint = convertPoint(toScreen: event.locationInWindow)
        return NSEvent.mouseEvent(
            with: event.type,
            location: parent.convertPoint(fromScreen: screenPoint),
            modifierFlags: event.modifierFlags,
            timestamp: event.timestamp,
            windowNumber: parent.windowNumber,
            context: nil,
            eventNumber: event.eventNumber,
            clickCount: event.clickCount,
            pressure: event.pressure
        )
    }
}

/// An `NSHostingView` that returns `nil` from `hitTest` for empty overlay area so clicks
/// fall through to the window beneath; hits on real notification content are returned.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        // A real AppKit subview was hit (e.g. an NSViewRepresentable): claim it.
        guard result === self else { return result }
        // SwiftUI content isn't exposed as NSView subviews, so `super.hitTest` returns
        // `self` for notification content and empty area alike. Tell them apart from the
        // layer tree instead (as the iOS 26 path does): a hit on the hosting view's own
        // layer means the point is over empty area. `point` is in the superview's
        // coordinate space, which is what `CALayer.hitTest` expects.
        guard let layer, let hitLayer = layer.hitTest(point), hitLayer !== layer else { return nil }
        return self
    }
}
#endif
