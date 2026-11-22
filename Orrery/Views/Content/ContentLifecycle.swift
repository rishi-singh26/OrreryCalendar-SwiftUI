//
//  ContentLifecycle.swift
//  Orrery
//
//  Lifecycle wiring shared by `SmallScreenView` and `LargeScreenView`: data bootstrap,
//  auto play settings/stop conditions, and range/ready handling.
//

import SwiftUI

/// Whether the ready/range `onChange`s also fire on mount.
enum ContentLifecycleObservation {
    /// Only react to later changes.
    case changesOnly
    /// Also run once on mount. The controller is shared across windows, so a window opened
    /// after it's already ready never sees those values change and must seed its selection
    /// and range thresholds from the current values.
    case includingCurrentState
}

private struct ContentLifecycleModifier: ViewModifier {
    @Environment(DataController.self) private var dataController
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage(AppStorageKeys.rangeYears) private var rangeYears = DataController.defaultRangeYears
    @AppStorage(AppStorageKeys.autoPlayEnabled) private var autoPlayEnabled = true
    @AppStorage(AppStorageKeys.autoPlayRate) private var autoPlayRate: AutoPlayRate = AutoPlayRate.defaultRate
    @AppStorage(AppStorageKeys.autoPlayDirection) private var autoPlayDirection: AutoPlayDirection = AutoPlayDirection.defaultDirection
    
    let viewModel: ContentViewModel
    let observing: ContentLifecycleObservation
    
    private var firesOnMount: Bool { observing == .includingCurrentState }
    
    func body(content: Content) -> some View {
        content
            .task {
                await dataController.bootstrap()
            }
            .onChange(of: autoPlayEnabled) { _, enabled in
                if !enabled { viewModel.autoPlay.stop() }
            }
            .onChange(of: autoPlayRate, initial: true) { _, newValue in viewModel.autoPlay.rate = newValue }
            .onChange(of: autoPlayDirection, initial: true) { _, newValue in viewModel.autoPlay.direction = newValue }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { viewModel.autoPlay.stop() }
            }
            .onDisappear {
                viewModel.autoPlay.stop()
            }
            .onChange(of: dataController.isReady, initial: firesOnMount) { _, ready in
                viewModel.handleReadyChange(isReady: ready, dataController: dataController, rangeYears: rangeYears)
            }
            .onChange(of: dataController.startDate, initial: firesOnMount) { _, _ in
                viewModel.handleRangeChange(dataController: dataController)
            }
            .onChange(of: dataController.endDate, initial: firesOnMount) { _, _ in
                viewModel.handleRangeChange(dataController: dataController)
            }
    }
}

extension View {
    func contentLifecycle(viewModel: ContentViewModel, observing: ContentLifecycleObservation) -> some View {
        modifier(ContentLifecycleModifier(viewModel: viewModel, observing: observing))
    }
}
