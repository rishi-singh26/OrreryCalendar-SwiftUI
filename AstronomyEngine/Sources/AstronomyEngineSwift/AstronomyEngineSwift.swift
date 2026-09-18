import CAstronomyEngine
import Foundation

/// The Sun, the 8 planets, and the Moon — the bodies this app cares about.
/// Cases map 1:1 onto the vendored C library's `astro_body_t` enum.
public enum CelestialBody: String, CaseIterable, Sendable {
    case mercury, venus, earth, mars, jupiter, saturn, uranus, neptune, sun, moon

    var cBody: astro_body_t {
        switch self {
        case .mercury: return BODY_MERCURY
        case .venus: return BODY_VENUS
        case .earth: return BODY_EARTH
        case .mars: return BODY_MARS
        case .jupiter: return BODY_JUPITER
        case .saturn: return BODY_SATURN
        case .uranus: return BODY_URANUS
        case .neptune: return BODY_NEPTUNE
        case .sun: return BODY_SUN
        case .moon: return BODY_MOON
        }
    }
}

/// The 8 planets, Sun→outward. This fixed order backs the packed-data layout used
/// throughout the app (see `PlanetEngineClient`), so don't reorder it casually.
public let orderedPlanets: [CelestialBody] = [
    .mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune,
]

public enum AstronomyEngineError: Error, Sendable {
    /// The C engine reported a non-success `astro_status_t` for this call.
    case computationFailed(String)
}

/// A `Date` already converted to the engine's internal `astro_time_t`. Opaque to
/// callers outside this module — obtain one via `AstronomyEngine.time(for:)` and reuse
/// it across multiple queries for the same instant (e.g. several bodies' distance +
/// angle, plus the Moon phase, all for one calendar day) instead of re-running the UTC
/// calendar conversion on every single query.
public struct AstronomyTime: Sendable {
    let raw: astro_time_t
}

/// Thin, idiomatic wrapper over the vendored Astronomy Engine C library
/// (cosinekitty/astronomy, pinned at tag v2.1.19 — see AstronomyEngine/LICENSE).
///
/// Every entry point ultimately needs the engine's `astro_time_t`, produced via the
/// library's own `Astronomy_MakeTime` UTC-calendar constructor — never via
/// hand-derived Julian-date math — using the UTC calendar/time-zone explicitly, so
/// results are independent of the caller's local time zone.
public enum AstronomyEngine {
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Converts `date` to the engine's time representation once. Prefer this plus the
    /// `time:`-taking overloads below when making several queries for the same instant
    /// — each conversion involves a `Calendar.dateComponents` round-trip, so batching
    /// avoids paying that cost once per query instead of once per instant.
    public static func time(for date: Date) -> AstronomyTime {
        let c = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        let second = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1_000_000_000
        let raw = Astronomy_MakeTime(
            Int32(c.year ?? 0), Int32(c.month ?? 1), Int32(c.day ?? 1),
            Int32(c.hour ?? 0), Int32(c.minute ?? 0), second
        )
        return AstronomyTime(raw: raw)
    }

    /// Heliocentric distance of `body` on `date`, in AU.
    public static func helioDistance(body: CelestialBody, date: Date) throws -> Double {
        try helioDistance(body: body, time: time(for: date))
    }

    /// Heliocentric distance of `body` at `time`, in AU.
    public static func helioDistance(body: CelestialBody, time: AstronomyTime) throws -> Double {
        let result = Astronomy_HelioDistance(body.cBody, time.raw)
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_HelioDistance(\(body)) failed with status \(result.status.rawValue)"
            )
        }
        return result.value
    }

    /// Ecliptic longitude of `body` on `date`, in degrees, 0..<360.
    public static func eclipticLongitude(body: CelestialBody, date: Date) throws -> Double {
        try eclipticLongitude(body: body, time: time(for: date))
    }

    /// Ecliptic longitude of `body` at `time`, in degrees, 0..<360.
    public static func eclipticLongitude(body: CelestialBody, time: AstronomyTime) throws -> Double {
        let result = Astronomy_EclipticLongitude(body.cBody, time.raw)
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_EclipticLongitude(\(body)) failed with status \(result.status.rawValue)"
            )
        }
        return result.angle
    }

    /// Moon phase angle on `date`, in degrees: 0 = new moon, 180 = full moon.
    public static func moonPhase(date: Date) throws -> Double {
        try moonPhase(time: time(for: date))
    }

    /// Moon phase angle at `time`, in degrees: 0 = new moon, 180 = full moon.
    public static func moonPhase(time: AstronomyTime) throws -> Double {
        let result = Astronomy_MoonPhase(time.raw)
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_MoonPhase failed with status \(result.status.rawValue)"
            )
        }
        return result.angle
    }

    /// Heliocentric Cartesian position of `body` at `time`, in AU. Private — an
    /// implementation detail of `distance(from:to:)` below, not a public primitive on
    /// its own.
    private struct HelioVector {
        let x, y, z: Double
    }

    private static func helioVector(body: CelestialBody, time: AstronomyTime) throws -> HelioVector {
        let v = Astronomy_HelioVector(body.cBody, time.raw)
        guard v.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_HelioVector(\(body)) failed with status \(v.status.rawValue)"
            )
        }
        return HelioVector(x: v.x, y: v.y, z: v.z)
    }

    /// Straight-line distance between `from` and `to` on `date`, in AU — the actual
    /// physical separation at that instant (via heliocentric vector subtraction), not
    /// `Astronomy_GeoVector`'s light-time-corrected apparent position.
    public static func distance(from: CelestialBody, to: CelestialBody, date: Date) throws -> Double {
        try distance(from: from, to: to, time: time(for: date))
    }

    /// Straight-line distance between `from` and `to` at `time`, in AU.
    public static func distance(from: CelestialBody, to: CelestialBody, time: AstronomyTime) throws -> Double {
        let a = try helioVector(body: from, time: time)
        let b = try helioVector(body: to, time: time)
        let dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    /// Sidereal orbital period of `body` around the Sun, in days. Only meaningful for
    /// `orderedPlanets` — not `.sun` or `.moon`.
    public static func orbitalPeriodDays(body: CelestialBody) -> Double {
        Astronomy_PlanetOrbitalPeriod(body.cBody)
    }

    /// Brightness/phase of `body` as seen from Earth.
    public struct Illumination: Sendable {
        /// Visual magnitude — smaller values are brighter.
        public let magnitude: Double
        /// Fraction of the body's apparent disc that's illuminated, 0...1.
        public let phaseFraction: Double
    }

    /// Illumination of `body` on `date`. Throws for `.earth` — the underlying engine
    /// rejects it, since "as seen from Earth" is undefined for Earth itself.
    public static func illumination(body: CelestialBody, date: Date) throws -> Illumination {
        try illumination(body: body, time: time(for: date))
    }

    /// Illumination of `body` at `time`. Throws for `.earth` (see above).
    public static func illumination(body: CelestialBody, time: AstronomyTime) throws -> Illumination {
        let result = Astronomy_Illumination(body.cBody, time.raw)
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_Illumination(\(body)) failed with status \(result.status.rawValue)"
            )
        }
        return Illumination(magnitude: result.mag, phaseFraction: result.phase_fraction)
    }
}
