//
//  RioVideoWallpaperUITestsLaunchTests.swift
//  RioVideoWallpaperUITests
//
//  Created by Rio Fujita on 2025/06/05.
//

import XCTest

final class RioVideoWallpaperUITestsLaunchTests: XCTestCase {
    private var runningApplication: XCUIApplication?
    private var testLibraryURL: URL?

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
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
    func testLaunch() throws {
        let app = try makeApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeApplication() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["VIDEO_WALLPAPER_UI_TESTING"] = "1"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RioVideoWallpaperLaunchTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        testLibraryURL = root
        app.launchEnvironment["VIDEO_WALLPAPER_TEST_LIBRARY_ROOT"] = root.path
        runningApplication = app
        return app
    }
}
