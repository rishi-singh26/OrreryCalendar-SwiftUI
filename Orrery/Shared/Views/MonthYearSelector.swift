//
//  MonthYearSelector.swift
//  Orrery
//
//  Created by Rishi Singh on 03/09/26.
//

import SwiftUI

struct MonthYearSelector: View {
    @Binding var selection: Date
    let minDate: Date
    let maxDate: Date

    private var calendar: Calendar { UTCDay.calendar }

    private var selectedComponents: DateComponents {
        calendar.dateComponents([.year, .month, .day], from: selection)
    }

    private var minYear: Int { calendar.component(.year, from: minDate) }
    private var maxYear: Int { calendar.component(.year, from: maxDate) }

    private var years: [Int] { Array(minYear...maxYear) }

    /// Months available for the currently selected year, clipped to `minDate`/`maxDate`
    /// when that year is the first or last year of the allowed range.
    private var months: [Int] {
        let year = selectedComponents.year ?? minYear
        let lower = year == minYear ? calendar.component(.month, from: minDate) : 1
        let upper = year == maxYear ? calendar.component(.month, from: maxDate) : 12
        guard lower <= upper else { return [lower] }
        return Array(lower...upper)
    }

    /// `UTCDay.calendar` has no `.locale` set (it only fixes `.timeZone` to UTC for
    /// day-keying math), so its own `monthSymbols` falls back to generic placeholders
    /// ("M01", "M02", …) instead of localized names. Ask a locale-aware copy for the
    /// symbols instead; the UTC calendar above still does all the date arithmetic.
    private var monthSymbols: [String] {
        var localizedCalendar = calendar
        localizedCalendar.locale = .current
        return localizedCalendar.monthSymbols
    }

    var body: some View {
        HStack {
            Picker("Month", selection: monthBinding) {
                ForEach(months, id: \.self) { month in
                    Text(monthSymbols[month - 1]).tag(month)
                }
            }
            .labelsHidden()

            Picker("Year", selection: yearBinding) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .labelsHidden()
        }
        .pickerStyle(.menu)
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { selectedComponents.month ?? 1 },
            set: { selection = date(forYear: selectedComponents.year ?? minYear, month: $0) }
        )
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { selectedComponents.year ?? minYear },
            set: { selection = date(forYear: $0, month: selectedComponents.month ?? 1) }
        )
    }

    /// Builds a date for the given year/month, keeping the current day-of-month where
    /// possible (clamped to the target month's length), then clamps into
    /// `minDate...maxDate` so an edge-of-range pick can't land outside the cached range.
    private func date(forYear year: Int, month: Int) -> Date {
        var comps = selectedComponents
        comps.year = year
        comps.month = month
        if let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
           let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) {
            comps.day = min(comps.day ?? 1, dayRange.count)
        }
        let candidate = calendar.date(from: comps) ?? selection
        return min(max(candidate, minDate), maxDate)
    }
}

#Preview {
    @Previewable @State var selectedDate: Date = .now
    MonthYearSelector(
        selection: $selectedDate,
        minDate: Calendar.current.date(byAdding: .year, value: -10, to: .now)!,
        maxDate: Calendar.current.date(byAdding: .year, value: 10, to: .now)!
    )
}
