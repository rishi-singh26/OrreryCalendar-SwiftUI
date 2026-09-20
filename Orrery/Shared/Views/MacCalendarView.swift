//
//  MacCalendarView.swift
//  Orrery
//
//  Themed replacement for the native `.graphical` `DatePicker` on macOS — AppKit's
//  calendar-style picker always renders with stock system chrome (plain grid, system
//  accent) regardless of `ThemeColors`. Used only on macOS (see `LargeScreenView`);
//  other platforms keep the native graphical picker, which already matches its host
//  UI well enough there.
//

import SwiftUI

/// Pure month-grid math for `MacCalendarView`, kept separate so the day-layout logic
/// stays testable independent of the view.
enum MacCalendarMath {
    /// The 42 `Date`s (6 full Sunday-through-Saturday weeks) that cover `month` — always
    /// 42 regardless of the month's actual length, so the grid's height never shifts as
    /// the displayed month changes.
    static func grid(for month: Date) -> [Date] {
        let calendar = UTCDay.calendar
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start
        else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

struct MacCalendarView: View {
    @Binding var selection: Date
    let minDate: Date
    let maxDate: Date
    let today: Date
    let theme: ThemeColors

    @State private var displayedMonth: Date
    @State private var hoveredDate: Date?

    private var calendar: Calendar { UTCDay.calendar }

    init(selection: Binding<Date>, minDate: Date, maxDate: Date, today: Date, theme: ThemeColors) {
        self._selection = selection
        self.minDate = minDate
        self.maxDate = maxDate
        self.today = today
        self.theme = theme
        self._displayedMonth = State(initialValue: UTCDay.midnight(of: selection.wrappedValue))
    }

    /// `UTCDay.calendar` has no `.locale` set (only its `.timeZone` is fixed, for
    /// day-keying math), so its own symbol arrays fall back to generic placeholders
    /// instead of localized names — ask a locale-aware copy for display strings instead,
    /// same trick `MonthYearSelector` uses for its month names.
    private var monthSymbols: [String] {
        var localizedCalendar = calendar
        localizedCalendar.locale = .current
        return localizedCalendar.monthSymbols
    }

    private var weekdaySymbols: [String] {
        var localizedCalendar = calendar
        localizedCalendar.locale = .current
        return localizedCalendar.veryShortStandaloneWeekdaySymbols
    }

    private var monthTitle: String {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        let name = monthSymbols[(comps.month ?? 1) - 1]
        return "\(name) \(comps.year ?? 0)"
    }

    private var canGoPrevious: Bool {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        return monthEnd(of: previous) >= UTCDay.midnight(of: minDate)
    }

    private var canGoNext: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return false }
        return monthStart(of: next) <= UTCDay.midnight(of: maxDate)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            grid
        }
        // Keeps the displayed month in step with `selection` whenever it changes from
        // outside this view (e.g. `MonthYearSelector` above it, or the toolbar's "Today"
        // button) — but not when the user merely browses with the chevrons below, which
        // intentionally moves `displayedMonth` without touching `selection`.
        .onChange(of: selection) { _, newValue in
            let newMonth = monthStart(of: newValue)
            if newMonth != monthStart(of: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }

    private var header: some View {
        HStack {
            monthStepButton(systemName: "chevron.left", enabled: canGoPrevious) { step(by: -1) }

            Spacer()

            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(theme.ink)

            Spacer()

            monthStepButton(systemName: "chevron.right", enabled: canGoNext) { step(by: 1) }
        }
    }

    private func monthStepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? theme.ink : theme.muted.opacity(0.35))
        .disabled(!enabled)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.muted)
                    .frame(width: 32)
            }
        }
    }

    private var grid: some View {
        let days = MacCalendarMath.grid(for: displayedMonth)
        let columns = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                dayCell(for: day)
            }
        }
    }

    @ViewBuilder
    private func dayCell(for day: Date) -> some View {
        let isCurrentMonth = monthStart(of: day) == monthStart(of: displayedMonth)
        let isSelected = day == UTCDay.midnight(of: selection)
        let isToday = day == UTCDay.midnight(of: today)
        let isInRange = day >= UTCDay.midnight(of: minDate) && day <= UTCDay.midnight(of: maxDate)
        let dayNumber = calendar.component(.day, from: day)

        Button {
            selection = day
        } label: {
            Text("\(dayNumber)")
                .font(.system(size: 13, weight: isSelected || isToday ? .semibold : .regular))
                .monospacedDigit()
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle().fill(Color.accentColor)
                    } else if hoveredDate == day && isInRange {
                        Circle().fill(theme.hairline)
                    }
                }
                .overlay {
                    if isToday && !isSelected {
                        Circle().stroke(Color.accentColor, lineWidth: 1.25)
                    }
                }
                .foregroundStyle(foregroundColor(isSelected: isSelected, isToday: isToday, isCurrentMonth: isCurrentMonth, isInRange: isInRange))
        }
        .buttonStyle(.plain)
        .disabled(!isInRange)
        .onHover { hovering in
            hoveredDate = hovering ? day : (hoveredDate == day ? nil : hoveredDate)
        }
    }

    private func foregroundColor(isSelected: Bool, isToday: Bool, isCurrentMonth: Bool, isInRange: Bool) -> Color {
        guard isInRange else { return theme.muted.opacity(0.3) }
        if isSelected { return theme.background }
        if isToday { return Color.accentColor }
        return isCurrentMonth ? theme.ink : theme.muted.opacity(0.6)
    }

    private func monthStart(of date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func monthEnd(of date: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return date }
        return calendar.date(byAdding: .day, value: -1, to: interval.end) ?? date
    }

    private func step(by months: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: months, to: displayedMonth) else { return }
        displayedMonth = newMonth
    }
}

#Preview {
    @Previewable @State var selectedDate: Date = .now
    MacCalendarView(
        selection: $selectedDate,
        minDate: Calendar.current.date(byAdding: .year, value: -10, to: .now)!,
        maxDate: Calendar.current.date(byAdding: .year, value: 10, to: .now)!,
        today: .now,
        theme: .light
    )
    .padding()
}
