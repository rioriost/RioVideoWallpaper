//
//  RioVideoWallpaperUITests.swift
//  RioVideoWallpaperUITests
//
//  Created by Rio Fujita on 2025/06/05.
//

import XCTest

final class RioVideoWallpaperUITests: XCTestCase {
    private var runningApplication: XCUIApplication?
    private var testLibraryURL: URL?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        runningApplication?.terminate()
        runningApplication = nil
        if let testLibraryURL {
            try FileManager.default.removeItem(at: testLibraryURL)
            self.testLibraryURL = nil
        }
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = try makeApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testGenerativeEditorOpensFromLaunchEnvironment() throws {
        let app = try makeApplication()
        app.launchEnvironment["VIDEO_WALLPAPER_OPEN_GENERATIVE_EDITOR"] = "1"
        app.launch()

        let exportButton = app.buttons["export-video"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["preview-first-frame"].exists)
        XCTAssertTrue(app.buttons["preview-play-pause"].exists)
        XCTAssertFalse(app.staticTexts["Provider"].exists)
        XCTAssertFalse(app.staticTexts["Intent"].exists)
        app.buttons["preview-first-frame"].click()
        app.buttons["preview-play-pause"].click()
        app.buttons["preview-first-frame"].click()
    }

    @MainActor
    func testLaunchSmoke() throws {
        let app = try makeApplication()
        app.launch()
        let launched = app.wait(for: .runningForeground, timeout: 2) ||
            app.wait(for: .runningBackground, timeout: 2)
        XCTAssertTrue(launched)
    }

    private func makeApplication() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["VIDEO_WALLPAPER_UI_TESTING"] = "1"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RioVideoWallpaperUITests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        testLibraryURL = root
        app.launchEnvironment["VIDEO_WALLPAPER_TEST_LIBRARY_ROOT"] = root.path
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        runningApplication = app
        return app
    }
}
