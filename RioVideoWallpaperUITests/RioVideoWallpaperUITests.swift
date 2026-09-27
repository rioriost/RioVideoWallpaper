//
//  RioVideoWallpaperUITests.swift
//  RioVideoWallpaperUITests
//
//  Created by Rio Fujita on 2025/06/05.
//

import XCTest

final class RioVideoWallpaperUITests: XCTestCase {
    private var runningApplication: XCUIApplication?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        runningApplication?.terminate()
        runningApplication = nil
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = makeApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testGenerativeEditorOpensFromLaunchEnvironment() throws {
        let app = makeApplication()
        app.launchEnvironment["VIDEO_WALLPAPER_OPEN_GENERATIVE_EDITOR"] = "1"
        app.launch()

        let window = app.windows["RioVideoWallpaper"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.buttons["Export"].exists)
        XCTAssertTrue(window.buttons["Set to All Displays"].exists)
        XCTAssertTrue(window.buttons["Set on Display..."].exists)
        XCTAssertTrue(window.buttons["Remove orphaned generated assets"].exists)
        XCTAssertTrue(window.buttons["Pause"].exists || window.buttons["Play"].exists)
        XCTAssertTrue(window.buttons["Go To End"].exists)
        XCTAssertTrue(window.buttons["Go To Start"].exists)
        XCTAssertTrue(window.buttons["Preview Loop Seam"].exists)
        XCTAssertTrue(window.staticTexts["Renderer"].exists)
        XCTAssertTrue(window.staticTexts["Export Options"].exists)
        XCTAssertTrue(window.staticTexts["Renderer Options"].exists)
    }

    @MainActor
    func testLaunchSmoke() throws {
        let app = makeApplication()
        app.launch()
        let launched = app.wait(for: .runningForeground, timeout: 2) ||
            app.wait(for: .runningBackground, timeout: 2)
        XCTAssertTrue(launched)
    }

    private func makeApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["VIDEO_WALLPAPER_UI_TESTING"] = "1"
        runningApplication = app
        return app
    }
}
