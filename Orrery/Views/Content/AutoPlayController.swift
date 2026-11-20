//
//  AutoPlayController.swift
//  Orrery
//
//  Drives the auto play feature: while playing, advances a date at a constant rate of
//  days per second. Knows nothing about SwiftUI or `DataController` — the owner supplies
//  the date range and a closure that applies each new date. Only `isPlaying` is
//  observed; everything else is `@ObservationIgnored` so playback never invalidates views
//  beyond the Play/Pause button.
//

import Foundation
import Observation

@MainActor
@Observable
final class AutoPlayController {
    private(set) var isPlaying = false

    @ObservationIgnored var rate: AutoPlayRate = AutoPlayRate.defaultRate
    @ObservationIgnored var direction: AutoPlayDirection = AutoPlayDirection.defaultDirection

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Target ~15 date updates per second regardless of rate.
    private static let tickInterval: Duration = .milliseconds(66)
    /// Caps the elapsed time credited to one tick so a stall can't cause a big jump.
    private static let maxElapsed: Double = 0.25

    /// Result of one stepping computation.
    struct Step: Equatable {
        var date: Date
        var hitEdge: Bool
    }

    /// Moves `date` by `days` (signed by `sign`) and clamps into `min...max`.
    /// `hitEdge` is true when the result sits on the edge it was moving toward.
    nonisolated static func step(from date: Date, days: Int, sign: Int, min: Date, max: Date) -> Step {
        let moved = UTCDay.calendar.date(byAdding: .day, value: days * sign, to: date) ?? date
        if moved >= max, sign > 0 { return Step(date: max, hitEdge: true) }
        if moved <= min, sign < 0 { return Step(date: min, hitEdge: true) }
        return Step(date: moved, hitEdge: false)
    }

    func toggle(
        currentDate: @escaping @MainActor () -> Date,
        range: @escaping @MainActor () -> ClosedRange<Date>,
        apply: @escaping @MainActor (Date) -> Void
    ) {
        if isPlaying {
            stop()
        } else {
            start(currentDate: currentDate, range: range, apply: apply)
        }
    }

    func start(
        currentDate: @escaping @MainActor () -> Date,
        range: @escaping @MainActor () -> ClosedRange<Date>,
        apply: @escaping @MainActor (Date) -> Void
    ) {
        task?.cancel()
        isPlaying = true
        task = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            var accumulatedDays = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tickInterval)
                guard !Task.isCancelled, let self else { return }
                let now = clock.now
                let elapsed = min((now - last).seconds, Self.maxElapsed)
                last = now
                accumulatedDays += elapsed * self.rate.daysPerSecond
                let whole = Int(accumulatedDays.rounded(.down))
                guard whole >= 1 else { continue }
                accumulatedDays -= Double(whole)

                let bounds = range()
                let result = Self.step(
                    from: currentDate(), days: whole, sign: self.direction.sign,
                    min: bounds.lowerBound, max: bounds.upperBound
                )
                apply(result.date)
                if result.hitEdge {
                    self.stop()
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if isPlaying { isPlaying = false }
    }
}

private extension Duration {
    var seconds: Double {
        let c = components
        return Double(c.seconds) + Double(c.attoseconds) / 1e18
    }
}
