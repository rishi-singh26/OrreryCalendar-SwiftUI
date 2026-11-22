//
//  OrreryUITests.swift
//  OrreryUITests
//
//  Created by Rishi Singh on 02/09/26.
//

import XCTest

final class OrreryUITests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        
        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
        
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }
    
    /// Regression test: on a fresh launch the Auto Play speed notch must reflect the saved
    /// speed, not the first slot ("1D"). The launch argument sets `autoPlayRate` for this
    /// run only (it goes in the argument domain of `UserDefaults`, which `@AppStorage` reads).
    @MainActor
    func testAutoPlaySpeedNotchShowsSavedSpeedOnLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-autoPlayRate", "month1"]
        app.launch()
        
        let play = app.buttons["Auto play"]
        XCTAssertTrue(play.waitForExistence(timeout: 30))
        // The button stays disabled until the planet data has loaded.
        let isEnabled = NSPredicate(format: "isEnabled == true")
        wait(for: [XCTNSPredicateExpectation(predicate: isEnabled, object: play)], timeout: 60)
        play.tap()
        
        // The notch is only exposed to accessibility while playing.
        let notch = app.descendants(matching: .any)["Auto play speed"]
        XCTAssertTrue(notch.waitForExistence(timeout: 10))
        XCTAssertEqual(notch.value as? String, "1 Month per Sec")
        
        play.tap() // pause
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
