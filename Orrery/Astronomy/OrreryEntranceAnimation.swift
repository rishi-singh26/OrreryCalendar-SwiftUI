//
//  OrreryEntranceAnimation.swift
//  Orrery
//
//  Timing for `OrreryView`'s one-time "loading → ready" entrance: each planet eases
//  from `OrreryGeometry.loadingAngleDeg` into its real position independently, on its
//  own duration — outer orbits (a longer arc to sweep) run a bit longer than inner
//  ones, so the motion visibly staggers outward rather than every planet landing in
//  lockstep. Pure timing/easing math, kept separate from `OrreryGeometry` (position
//  math) since this is animation policy, not geometry — same split as
//  `ScrubTimelineMath` living apart from the views that use it.
//

import Foundation

enum OrreryEntranceAnimation {
    /// Entrance duration for the innermost orbit (Mercury).
    static let minDuration: TimeInterval = 0.5

    /// Entrance duration for the outermost orbit (Neptune) — also how long
    /// `OrreryView` keeps its `TimelineView` ticking, since it's the last planet to
    /// settle. Every orbit in between is linearly interpolated between this and
    /// `minDuration` by `duration(forOrbitIndex:count:)`.
    static let maxDuration: TimeInterval = 1.3

    /// Per-orbit entrance duration: `minDuration` at index 0, `maxDuration` at
    /// `count - 1`, linear in between.
    static func duration(forOrbitIndex index: Int, count: Int) -> TimeInterval {
        guard count > 1 else { return minDuration }
        let t = Double(index) / Double(count - 1)
        return minDuration + (maxDuration - minDuration) * t
    }

    /// Cubic ease-out: departs the loading pose quickly, then settles gently into the
    /// real position — "start quickly and ease out at the end."
    static func easeOut(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    /// Eased `0...1` progress for the orbit-`index`-th (of `count`) planet, `elapsed`
    /// seconds into the shared entrance animation. Reaches — and stays at — `1` once
    /// that planet's own duration has passed, even while slower, outer planets are
    /// still moving.
    static func progress(elapsed: TimeInterval, orbitIndex: Int, orbitCount: Int) -> Double {
        let duration = duration(forOrbitIndex: orbitIndex, count: orbitCount)
        guard duration > 0 else { return 1 }
        return easeOut(elapsed / duration)
    }
}
