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

/// Thin, idiomatic wrapper over the vendored Astronomy Engine C library
/// (cosinekitty/astronomy, pinned at tag v2.1.19 — see AstronomyEngine/LICENSE).
///
/// Every entry point takes a `Date` and converts it to the engine's `astro_time_t`
/// via the library's own `Astronomy_MakeTime` UTC-calendar constructor — never via
/// hand-derived Julian-date math — using the UTC calendar/time-zone explicitly, so
/// results are independent of the caller's local time zone.
public enum AstronomyEngine {
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func astroTime(for date: Date) -> astro_time_t {
        let c = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        let second = Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1_000_000_000
        return Astronomy_MakeTime(
            Int32(c.year ?? 0), Int32(c.month ?? 1), Int32(c.day ?? 1),
            Int32(c.hour ?? 0), Int32(c.minute ?? 0), second
        )
    }

    /// Heliocentric distance of `body` on `date`, in AU.
    public static func helioDistance(body: CelestialBody, date: Date) throws -> Double {
        let result = Astronomy_HelioDistance(body.cBody, astroTime(for: date))
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_HelioDistance(\(body)) failed with status \(result.status.rawValue)"
            )
        }
        return result.value
    }

    /// Ecliptic longitude of `body` on `date`, in degrees, 0..<360.
    public static func eclipticLongitude(body: CelestialBody, date: Date) throws -> Double {
        let result = Astronomy_EclipticLongitude(body.cBody, astroTime(for: date))
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_EclipticLongitude(\(body)) failed with status \(result.status.rawValue)"
            )
        }
        return result.angle
    }

    /// Moon phase angle on `date`, in degrees: 0 = new moon, 180 = full moon.
    public static func moonPhase(date: Date) throws -> Double {
        let result = Astronomy_MoonPhase(astroTime(for: date))
        guard result.status == ASTRO_SUCCESS else {
            throw AstronomyEngineError.computationFailed(
                "Astronomy_MoonPhase failed with status \(result.status.rawValue)"
            )
        }
        return result.angle
    }
}
