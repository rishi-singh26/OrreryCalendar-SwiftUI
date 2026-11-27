//
//  RangeExtensionPromptTests.swift
//  OrreryTests
//
//  When the "extend the cached range" button and toast show, and where the toast goes.
//

import Testing
import Foundation
@testable import Orrery

@MainActor
struct RangeExtensionPromptTests {
    /// A controller holding a freshly computed default range, and a view model synced to it.
    private func makeReady() async throws -> (DataController, ContentViewModel) {
        let dataController = DataController(modelContainer: try ModelContainerFactory.make(inMemory: true))
        await dataController.bootstrap()
        try #require(dataController.isReady)
        let viewModel = ContentViewModel()
        viewModel.handleRangeChange(dataController: dataController)
        return (dataController, viewModel)
    }
    
    private func day(_ offset: Int, from date: Date) -> Date {
        UTCDay.calendar.date(byAdding: .day, value: offset, to: date)!
    }
    
    @Test func promptShowsWithin30DaysOfEitherEnd() async throws {
        let (dataController, viewModel) = try await makeReady()
        let cases: [(Date, Bool)] = [
            (dataController.startDate, true),
            (day(29, from: dataController.startDate), true),
            (day(30, from: dataController.startDate), false),
            (day(-30, from: dataController.endDate), false),
            (day(-29, from: dataController.endDate), true),
            (dataController.endDate, true),
        ]
        for (date, expected) in cases {
            viewModel.selectedDate = date
            #expect(viewModel.showsRangeExtensionPrompt(dataController: dataController) == expected, "\(date)")
        }
    }
    
    @Test func settingsPanelHidesPromptWithoutResolvingIt() async throws {
        let (dataController, viewModel) = try await makeReady()
        viewModel.selectedDate = dataController.endDate
        viewModel.controlPresentationState = .settings
        #expect(!viewModel.showsRangeExtensionPrompt(dataController: dataController))
        #expect(viewModel.canSuggestRangeExtension(dataController: dataController))
    }
    
    @Test func onlyTheLargestRangeCountsAsMaximum() throws {
        let today = UTCDay.todayAsUTCMidnight()
        func dayCount(years: Int) throws -> Int {
            let start = try #require(UTCDay.calendar.date(byAdding: .year, value: -years, to: today))
            let end = try #require(UTCDay.calendar.date(byAdding: .year, value: years, to: today))
            return try UTCDay.dayCount(from: start, to: end) + 1
        }
        #expect(DataController.isMaxRange(dayCount: try dayCount(years: DataController.maxRangeYears)))
        #expect(!DataController.isMaxRange(dayCount: try dayCount(years: 50)))
    }
    
    @Test func actionToastStaysInTheWindowThatPostedIt() {
        let manager = InAppNotificationManager.shared
        let first = UUID(), second = UUID()
        manager.registerWindow(first)
        manager.registerWindow(second)
        manager.markWindowActive(second)
        defer {
            manager.unregisterWindow(first)
            manager.unregisterWindow(second)
        }
        func post(in window: UUID) -> UUID {
            manager.showActionToast(title: "T", systemImage: "gear", actionTitle: "A", in: window) {}
        }
        func window(of id: UUID) -> UUID? {
            manager.notificationQueue.first { $0.id == id }?.windowID
        }
        
        let a = post(in: first)
        let b = post(in: second)
        #expect(window(of: a) == first)
        #expect(window(of: b) == second)
        
        // Closing a window drops its toast instead of handing it to another window.
        manager.unregisterWindow(first)
        #expect(!manager.notificationQueue.contains { $0.id == a })
        #expect(window(of: b) == second)
        manager.removeNotification(b)
    }
}
