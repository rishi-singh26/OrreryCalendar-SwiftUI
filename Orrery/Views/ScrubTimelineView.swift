//
//  ScrubTimelineView.swift
//  Orrery
//
//  Horizontal draggable date scroller (spec §5): tick marks with month/year labels, a
//  brass center marker for the selected date, snapping to whole days. Major ticks fall
//  on the 1st of each month; minor ticks mark the other days. Clamps to the cached
//  range rather than requesting a day outside it.
//
//  `selectedDate` is updated continuously as the drag/scroll gesture progresses (not
//  just when it ends), so the chart tracks the timeline live.
//

import SwiftUI

/// Turns a stream of small, continuous scroll deltas into whole-day steps without
/// losing any input between events.
///
/// `DragGesture.translation` is cumulative from gesture start, so the drag handler can
/// safely round-to-nearest-day on every single callback — it's always recomputing from
/// the same fixed start point, so nothing is lost between calls. A `NSEvent.scrollWheel`
/// stream has no such cumulative value: each event carries only its own small
/// incremental delta (often a fraction of a point on precise-scrolling trackpads/mice,
/// arriving dozens of times a second). Rounding each of those independently — as the
/// drag handler does — discards almost every event, since most individual deltas round
/// to zero days on their own; that's what made scrolling feel dead/unsmooth. This type
/// instead keeps a running fractional-day remainder across events, so every bit of
/// scroll input eventually contributes and the date advances at a rate that tracks
/// scroll speed, rather than in occasional, arbitrary jumps.
struct ScrollDayAccumulator {
    private(set) var remainder: Double = 0

    /// Adds `deltaPoints` (already sign-adjusted so positive means "move forward in
    /// time") to the running remainder and returns however many whole days it now
    /// covers, keeping the leftover fraction for the next call.
    mutating func consume(deltaPoints: Double, pointsPerDay: Double) -> Int {
        remainder += deltaPoints / pointsPerDay
        let wholeDays = Int(remainder.rounded(.towardZero))
        remainder -= Double(wholeDays)
        return wholeDays
    }

    /// Drops any accumulated remainder — call after a step gets clamped at a range
    /// boundary, so debt doesn't silently build up while scrolling stays pinned there.
    mutating func reset() {
        remainder = 0
    }
}

struct ScrubTimelineView: View {
    @Binding var selectedDate: Date
    let minDate: Date
    let maxDate: Date
    let theme: ThemeColors

    /// Horizontal spacing between adjacent days, in points.
    private let pointsPerDay: Double = 10

    /// `selectedDate` at the moment the current drag gesture began. `DragGesture`'s
    /// `translation` is cumulative from gesture start, so every `onChanged` computes the
    /// new date from this fixed anchor rather than from the (now constantly moving)
    /// `selectedDate` — otherwise each event would compound on top of the last.
    @State private var dragAnchorDate: Date?

    /// Fractional days of scroll input not yet applied to `selectedDate` (see
    /// `ScrollDayAccumulator` below for why this exists).
    @State private var scrollAccumulator = ScrollDayAccumulator()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Canvas { context, canvasSize in
                    drawTicks(context: context, size: canvasSize, centerDate: selectedDate)
                }
                Rectangle()
                    .fill(theme.brass)
                    .frame(width: 2, height: size.height * 0.42)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let anchor = dragAnchorDate ?? selectedDate
                        if dragAnchorDate == nil { dragAnchorDate = anchor }
                        applyDayDelta(dayDelta(forPoints: -value.translation.width), from: anchor)
                    }
                    .onEnded { _ in
                        dragAnchorDate = nil
                    }
            )
            #if os(macOS)
            .background(
                ScrollWheelCapture { deltaX in
                    applyScrollDelta(deltaX)
                }
            )
            #endif
        }
        .frame(height: 64)
    }

    private func dayDelta(forPoints points: Double) -> Int {
        Int((points / pointsPerDay).rounded())
    }

    private func applyDayDelta(_ dayDelta: Int, from anchor: Date) {
        guard dayDelta != 0, let candidate = UTCDay.calendar.date(byAdding: .day, value: dayDelta, to: anchor) else { return }
        let clamped = min(max(candidate, minDate), maxDate)
        if clamped != selectedDate {
            selectedDate = clamped
        }
    }

    /// Feeds one scroll event's delta through `scrollAccumulator` and steps
    /// `selectedDate` by whatever whole days it now reports.
    private func applyScrollDelta(_ deltaX: CGFloat) {
        let wholeDays = scrollAccumulator.consume(deltaPoints: Double(-deltaX), pointsPerDay: pointsPerDay)
        guard wholeDays != 0 else { return }

        guard let candidate = UTCDay.calendar.date(byAdding: .day, value: wholeDays, to: selectedDate) else {
            scrollAccumulator.reset()
            return
        }
        let clamped = min(max(candidate, minDate), maxDate)
        let actualDays = (try? UTCDay.dayCount(from: selectedDate, to: clamped)) ?? wholeDays

        if clamped != selectedDate {
            selectedDate = clamped
        }

        if actualDays != wholeDays {
            // Hit (or was already at) the range boundary: drop the rest of the
            // accumulator rather than let "scroll debt" build up while pinned, which
            // would otherwise require an equally long scroll the other way before
            // anything moved again.
            scrollAccumulator.reset()
        }
    }

    private func drawTicks(context: GraphicsContext, size: CGSize, centerDate: Date) {
        let midX = size.width / 2
        let visibleDaysHalf = Int((size.width / 2 / pointsPerDay).rounded(.up)) + 2

        for offset in -visibleDaysHalf...visibleDaysHalf {
            guard let date = UTCDay.calendar.date(byAdding: .day, value: offset, to: centerDate) else { continue }
            guard date >= minDate, date <= maxDate else { continue }

            let x = midX + Double(offset) * pointsPerDay
            let isMajor = UTCDay.calendar.component(.day, from: date) == 1
            let tickHeight = size.height * (isMajor ? 0.5 : 0.25)

            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height))
            path.addLine(to: CGPoint(x: x, y: size.height - tickHeight))
            context.stroke(
                path,
                with: .color(isMajor ? theme.tickMajor : theme.tickMinor),
                lineWidth: isMajor ? 1.5 : 1
            )

            if isMajor {
                let label = Text(Self.monthYearFormatter.string(from: date))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(theme.tickLabel)
                context.draw(label, at: CGPoint(x: x, y: size.height - tickHeight - 6), anchor: .bottom)
            }
        }
    }

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

#if os(macOS)
import AppKit

/// Trackpad/scroll-wheel support for the timeline on macOS (spec §5: "drag gesture +
/// optional scroll wheel/trackpad support"). Uses a local `NSEvent` monitor rather than
/// overriding `scrollWheel(with:)` on a plain `NSView` — a bare `NSViewRepresentable`
/// layered under SwiftUI content is not reliably part of the hit-tested responder
/// chain for scroll events, so overriding `scrollWheel` alone silently does nothing in
/// that configuration. The monitor instead checks the cursor position against this
/// view's bounds on every scroll event in the app, independent of hit-testing/z-order.
private struct ScrollWheelCapture: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    final class Coordinator {
        var onScroll: (CGFloat) -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func attach(to view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.view, let window = view.window, window.isKeyWindow else {
                    return event
                }
                let locationInView = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(locationInView) else { return event }
                self.onScroll(event.scrollingDeltaX)
                return nil // consume: don't also let it scroll some ancestor
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
#endif
