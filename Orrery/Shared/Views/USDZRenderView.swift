//
//  USDZRenderView.swift
//  Orrery
//
//  Created by Rishi Singh on 15/09/26.
//

import SwiftUI
import RealityKit
import Combine

struct USDZRenderView: View {
    var name: String
    var isPlaying: Bool = true
    /// Bump (e.g. `+= 1`) to snap the model back to its resting orientation
    /// and zoom, undoing whatever the drag-to-rotate and pinch-to-zoom
    /// gestures below have accumulated.
    var resetTrigger: Int = 0
    @State var rootEntity = Entity()
    @State var modelEntity: Entity?
    @State var baseScale: Float = 1.0
    @State var userScale: Float = 1.0

    @State var orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @State var rotationSpeed: Float = .pi / 15
    @State var rotateLeft: Bool = false

    @State var lastDragTranslation: CGSize = .zero
    @State var isDragging = false
    let dragSensitivity: Float = 0.01

    // User-driven zoom via pinch (touch) or trackpad magnify (laptop).
    @State var scaleAtGestureStart: Float?
    let minUserScale: Float = 0.4
    let maxUserScale: Float = 4.0

    /// True while the reset-triggered `entity.move(to:)` animation is playing.
    /// Held off from the auto-rotate timer below so it doesn't fight
    /// RealityKit's own per-frame interpolation by setting
    /// `entity.transform.rotation` directly every tick; a new drag/pinch
    /// gesture starting mid-animation clears it and cancels the animation
    /// outright, so direct manipulation always wins.
    @State var isResetting = false
    let resetAnimationDuration: TimeInterval = 0.4

    static let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    // Fixed camera parameters — tweak these two to change zoom/margin.
    let cameraFOVDegrees: Float = 28
    let cameraDistance: Float = 0.32

    var body: some View {
        RealityView { content in
            // Opt out of the tightly-fit "automatic" camera and take control.
            content.camera = .virtual

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = cameraFOVDegrees
            camera.look(at: [0, 0, 0], from: [0, 0, cameraDistance], relativeTo: nil)
            content.add(camera)

            // A virtual camera opts out of the AR session, so RealityKit no
            // longer supplies automatic environment lighting. Without lights,
            // the USDZ's PBR materials render black. Add explicit lights.
            let keyLight = DirectionalLight()
            keyLight.light.intensity = 5000
            keyLight.look(at: [0, 0, 0], from: [1, 1, 1], relativeTo: nil)
            content.add(keyLight)

            let fillLight = DirectionalLight()
            fillLight.light.intensity = 2000
            fillLight.look(at: [0, 0, 0], from: [-1, 0.5, 0.5], relativeTo: nil)
            content.add(fillLight)

            // Add a persistent root so the model can be swapped out when the
            // selected planet changes without tearing down camera and lights.
            content.add(rootEntity)
        }
        .task(id: name) {
            await loadModel(named: name)
        }
        .onReceive(Self.timer) { _ in
            guard isPlaying, !isDragging, !isResetting else { return }
            let dt: Float = 1.0 / 60.0
            let direction: Float = rotateLeft ? -1.0 : 1.0
            let step = direction * abs(rotationSpeed) * dt
            orientation = orientation * simd_quatf(angle: step, axis: [0, 1, 0])
            applyRotation()
        }
        .onChange(of: resetTrigger) { _, _ in
            resetTransform()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        lastDragTranslation = .zero
                        cancelResetAnimationIfNeeded()
                    }
                    let deltaX = Float(value.translation.width - lastDragTranslation.width) * dragSensitivity
                    let deltaY = Float(value.translation.height - lastDragTranslation.height) * dragSensitivity
                    lastDragTranslation = value.translation
                    let yaw = simd_quatf(angle: deltaX, axis: [0, 1, 0])
                    let pitch = simd_quatf(angle: deltaY, axis: [1, 0, 0])
                    orientation = pitch * yaw * orientation
                    applyRotation()
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .simultaneousGesture(
            // Pinch on touch devices, trackpad magnify on laptops. Both arrive
            // as a MagnifyGesture; scale relative to where the gesture began so
            // repeated pinches accumulate rather than snapping back.
            MagnifyGesture()
                .onChanged { value in
                    if scaleAtGestureStart == nil {
                        cancelResetAnimationIfNeeded()
                    }
                    let start = scaleAtGestureStart ?? userScale
                    scaleAtGestureStart = start
                    userScale = min(max(start * Float(value.magnification), minUserScale), maxUserScale)
                    applyScale()
                }
                .onEnded { _ in
                    scaleAtGestureStart = nil
                }
        )
    }

    private func loadModel(named name: String) async {
        do {
            let loaded = try await Entity(named: name)
            let bounds = loaded.visualBounds(relativeTo: nil)
            let radius = max(bounds.boundingRadius, 0.0001)
            let targetRadius: Float = 0.08
            baseScale = targetRadius / radius

            // The USDZ's geometry can be offset from its local origin. Wrap
            // it in a pivot container and shift the model so its visual
            // center sits on the origin — otherwise scaling flings it off
            // screen, and rotation would orbit rather than spin in place.
            loaded.position = -bounds.center
            let container = Entity()
            container.addChild(loaded)
            container.transform.scale = SIMD3(repeating: baseScale * userScale)
            container.transform.rotation = orientation

            // Swap the previous planet's model out of the shared root.
            rootEntity.children.removeAll()
            rootEntity.addChild(container)
            modelEntity = container
        } catch {
            print("Failed to load entity:", error)
        }
    }

    private func applyRotation() {
        guard let entity = modelEntity else { return }
        // Only update rotation here. Scale is set once at load time; resetting
        // it every frame from `@State` risks reading a stale value and blowing
        // the model up so large the camera ends up inside it.
        entity.transform.rotation = orientation
    }

    private func applyScale() {
        guard let entity = modelEntity else { return }
        entity.transform.scale = SIMD3(repeating: baseScale * userScale)
    }

    private func resetTransform() {
        // Clears any in-flight pinch's cached start scale, so if a reset lands
        // mid-gesture the pinch recomputes its baseline from the freshly-reset
        // `userScale` on its next `.onChanged` instead of resuming from the
        // pre-reset value and undoing this reset.
        scaleAtGestureStart = nil
        orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        userScale = 1.0

        // SwiftUI's `withAnimation` has no effect on RealityKit entities — they
        // need to be told to animate directly via `move(to:)`. `applyRotation`/
        // `applyScale` are left for the timer/gesture call sites, which need an
        // instant, every-frame set; this is the only call site that wants a
        // smooth transition back to rest.
        guard let entity = modelEntity else { return }
        var target = entity.transform
        target.rotation = orientation
        target.scale = SIMD3(repeating: baseScale * userScale)

        isResetting = true
        entity.move(to: target, relativeTo: entity.parent, duration: resetAnimationDuration, timingFunction: .easeInOut)

        // Tagged with the trigger value that started this wait: if reset is
        // tapped again before this animation finishes, only the *latest*
        // reset's wait should clear `isResetting`. Without this check, this
        // earlier wait would fire first and let the auto-rotate timer resume
        // while the later animation it retriggered is still playing.
        let startedAtTrigger = resetTrigger
        Task {
            try? await Task.sleep(for: .seconds(resetAnimationDuration))
            guard resetTrigger == startedAtTrigger else { return }
            isResetting = false
        }
    }

    /// Called when a drag/pinch gesture begins — if a reset animation is still
    /// playing, direct manipulation should win outright rather than fight
    /// RealityKit's own per-frame interpolation for control of the transform.
    private func cancelResetAnimationIfNeeded() {
        guard isResetting else { return }
        isResetting = false
        modelEntity?.stopAllAnimations()
    }
}

fileprivate struct EarthDemo: View {
    var body: some View {
        ZStack {
            BackgroundView()
                .cornerRadius(30)
                .padding(5)
            
            USDZRenderView(name: "Earth 2")
        }
    }
}

#Preview {
    EarthDemo()
}
