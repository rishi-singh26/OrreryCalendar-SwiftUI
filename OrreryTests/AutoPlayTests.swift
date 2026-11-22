//
//  AutoPlayTests.swift
//  OrreryTests
//

import Testing
import Foundation
@testable import Orrery

struct AutoPlayTests {
    private func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
        UTCDay.calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }
    
    @Test func rateCountAndLabels() {
        #expect(AutoPlayRate.allCases.count == 11)
        #expect(AutoPlayRate.day1.label == "1 Day per Sec")
        #expect(AutoPlayRate.day2.label == "2 Days per Sec")
        #expect(AutoPlayRate.week3.label == "3 Weeks per Sec")
        #expect(AutoPlayRate.month1.label == "1 Month per Sec")
        #expect(AutoPlayRate.month2.label == "2 Months per Sec")
    }
    
    @Test func rateShortLabelsAreUniqueAndInDisplayOrder() {
        // The speed notch lists `allCases` top to bottom with these labels.
        let labels = AutoPlayRate.allCases.map(\.shortLabel)
        #expect(Set(labels).count == labels.count)
        #expect(labels == ["1D", "2D", "3D", "4D", "5D", "6D", "1W", "2W", "3W", "1M", "2M"])
    }
    
    @Test func rateDaysPerSecond() {
        #expect(AutoPlayRate.day6.daysPerSecond == 6)
        #expect(AutoPlayRate.week2.daysPerSecond == 14)
        #expect(abs(AutoPlayRate.month1.daysPerSecond - 30.436875) < 1e-9)
        #expect(abs(AutoPlayRate.month2.daysPerSecond - 2 * 30.436875) < 1e-9)
        let values = AutoPlayRate.allCases.map(\.daysPerSecond)
        #expect(values == values.sorted())
    }
    
    @Test func stepForwardAndBackward() {
        let lo = utc(2000, 1, 1), hi = utc(2050, 1, 1)
        #expect(AutoPlayController.step(from: utc(2024, 2, 28), days: 2, sign: 1, min: lo, max: hi)
                == .init(date: utc(2024, 3, 1), hitEdge: false)) // leap day crossed
        #expect(AutoPlayController.step(from: utc(2024, 3, 1), days: 2, sign: -1, min: lo, max: hi)
                == .init(date: utc(2024, 2, 28), hitEdge: false))
    }
    
    @Test func stepClampsAtEdges() {
        let lo = utc(2000, 1, 1), hi = utc(2050, 1, 1)
        #expect(AutoPlayController.step(from: utc(2049, 12, 30), days: 10, sign: 1, min: lo, max: hi)
                == .init(date: hi, hitEdge: true))
        #expect(AutoPlayController.step(from: utc(2000, 1, 3), days: 10, sign: -1, min: lo, max: hi)
                == .init(date: lo, hitEdge: true))
        #expect(AutoPlayController.step(from: hi, days: 1, sign: 1, min: lo, max: hi).hitEdge)
    }
}
