import Foundation
import Testing
@testable import RioVideoWallpaper

struct PlaybackRestorationTests {
    private let main = PlaybackSuspensionPolicy.ScreenSnapshot(
        width: 2560, height: 1440, displayID: "main"
    )
    private let side = PlaybackSuspensionPolicy.ScreenSnapshot(
        width: 1920, height: 1080, x: 2560, displayID: "side"
    )

    @Test func partialCoverageDoesNotSuspendVisibleDisplays() {
        let window = PlaybackSuspensionPolicy.WindowSnapshot(
            ownerPID: 42, layer: 0, width: 1920, height: 1080, x: 2560
        )
        #expect(PlaybackSuspensionPolicy.coveredDisplayIDs(
            frontmostPID: 42, currentPID: 7, windows: [window], screens: [main, side]
        ) == ["side"])
        #expect(!PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: false, frontmostPID: 42, currentPID: 7,
            windows: [window], screens: [main, side]
        ))
    }

    @Test func windowOnLargerDisplayDoesNotCoverSmallerDisplay() {
        let window = PlaybackSuspensionPolicy.WindowSnapshot(
            ownerPID: 42, layer: 0, width: 2000, height: 1200
        )
        #expect(PlaybackSuspensionPolicy.coveredDisplayIDs(
            frontmostPID: 42, currentPID: 7, windows: [window], screens: [main, side]
        ).isEmpty)
    }

    @Test func negativeScreenCoordinatesAndTransparencyAreRespected() {
        let screen = PlaybackSuspensionPolicy.ScreenSnapshot(
            width: 1920, height: 1080, x: -1920, y: -1080, displayID: "above-left"
        )
        var window = PlaybackSuspensionPolicy.WindowSnapshot(
            ownerPID: 42, layer: 0, width: 1920, height: 1080, x: -1920, y: -1080
        )
        #expect(PlaybackSuspensionPolicy.coveredDisplayIDs(
            frontmostPID: 42, currentPID: 7, windows: [window], screens: [screen]
        ) == ["above-left"])
        window.alpha = 0.5
        #expect(PlaybackSuspensionPolicy.coveredDisplayIDs(
            frontmostPID: 42, currentPID: 7, windows: [window], screens: [screen]
        ).isEmpty)
    }

    @Test func sharedSessionRunsWhileAnyConsumerIsVisible() {
        let a = URL(fileURLWithPath: "/tmp/a.mp4")
        let b = URL(fileURLWithPath: "/tmp/b.mp4")
        #expect(PlaybackSuspensionPolicy.suspendedVideoURLs(
            videoURLByDisplayID: ["main": a, "side": a],
            coveredDisplayIDs: ["side"], screensAreSleeping: false
        ).isEmpty)
        #expect(PlaybackSuspensionPolicy.suspendedVideoURLs(
            videoURLByDisplayID: ["main": a, "side": b],
            coveredDisplayIDs: ["side"], screensAreSleeping: false
        ) == [b])
        #expect(PlaybackSuspensionPolicy.suspendedVideoURLs(
            videoURLByDisplayID: ["main": a, "side": b],
            coveredDisplayIDs: [], screensAreSleeping: true
        ) == [a, b])
    }

    @Test func uncoveringWindowResumesSessionOnNextSnapshot() {
        let video = URL(fileURLWithPath: "/tmp/a.mp4")
        let window = PlaybackSuspensionPolicy.WindowSnapshot(
            ownerPID: 42, layer: 0, width: 2560, height: 1440
        )
        for windows in [[window], []] {
            let covered = PlaybackSuspensionPolicy.coveredDisplayIDs(
                frontmostPID: 42, currentPID: 7, windows: windows, screens: [main]
            )
            let suspended = PlaybackSuspensionPolicy.suspendedVideoURLs(
                videoURLByDisplayID: ["main": video],
                coveredDisplayIDs: covered, screensAreSleeping: false
            )
            #expect(suspended.isEmpty == windows.isEmpty)
        }
    }

    @Test func unavailableOverridePreservesStoredAssignmentAndUsesDefault() {
        let a = selection("a")
        let missing = selection("missing")
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: a, perDisplaySelections: ["side": missing]
        )
        let restored = DisplayWallpaperRestoration.restore(
            assignments, connectedDisplayIDs: ["main", "side"],
            resolve: { $0 }, isAccessible: { $0 == a.url }
        )
        #expect(restored.storedAssignments == assignments)
        #expect(restored.playbackAssignment?.videoURL(forDisplayID: "side") == a.url)
        #expect(restored.unavailableURLs == [missing.url])
    }

    @Test func disconnectedAssignmentsArePreservedWithoutRequestingAccess() {
        let a = selection("a")
        let offline = selection("offline")
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: a, perDisplaySelections: ["disconnected": offline]
        )
        var accessed: Set<URL> = []
        let restored = DisplayWallpaperRestoration.restore(
            assignments, connectedDisplayIDs: ["main"], resolve: { $0 },
            isAccessible: { accessed.insert($0); return $0 == a.url }
        )
        #expect(restored.storedAssignments == assignments)
        #expect(accessed == [a.url])
        #expect(restored.unavailableURLs.isEmpty)
    }

    @Test func missingDefaultUsesAvailableConnectedAssignmentWithoutSavingFallback() {
        let missing = selection("missing")
        let b = selection("b")
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: missing, perDisplaySelections: ["side": b]
        )
        let restored = DisplayWallpaperRestoration.restore(
            assignments, connectedDisplayIDs: ["main", "side"],
            resolve: { $0 == missing ? nil : $0 }, isAccessible: { _ in true }
        )
        #expect(restored.storedAssignments == assignments)
        #expect(restored.playbackAssignment?.defaultVideoURL == b.url)
        #expect(restored.unavailableURLs == [missing.url])
    }

    @Test func noAccessibleVideosLeavesSavedStateIntact() {
        let saved = StoredDisplayWallpaperAssignments(
            defaultSelection: selection("missing"), perDisplaySelections: [:]
        )
        let restored = DisplayWallpaperRestoration.restore(
            saved, connectedDisplayIDs: ["main"], resolve: { $0 }, isAccessible: { _ in false }
        )
        #expect(restored.storedAssignments == saved)
        #expect(restored.playbackAssignment == nil)
    }

    @Test func legacyMigrationIsPersistedOnceAndNewSettingsWin() throws {
        let suite = "PlaybackRestorationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DisplayWallpaperAssignmentStore(defaults: defaults)
        var migrationCalls = 0
        let migrated = try store.loadOrMigrate {
            migrationCalls += 1
            return selection("legacy")
        }
        #expect(migrated?.defaultSelection == selection("legacy"))
        #expect(try store.loadChecked() == migrated)
        let loaded = try store.loadOrMigrate {
            migrationCalls += 1
            return selection("other")
        }
        #expect(loaded == migrated)
        #expect(migrationCalls == 1)
    }

    @Test func unreadableNewSettingsAreNotOverwrittenByMigration() throws {
        let suite = "PlaybackRestorationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("invalid JSON".utf8)
        defaults.set(corrupt, forKey: DisplayWallpaperAssignmentStore.userDefaultsKey)
        let store = DisplayWallpaperAssignmentStore(defaults: defaults)
        #expect(throws: DecodingError.self) {
            try store.loadOrMigrate { selection("legacy") }
        }
        #expect(defaults.data(forKey: DisplayWallpaperAssignmentStore.userDefaultsKey) == corrupt)
    }

    private func selection(_ name: String) -> StoredWallpaperSelection {
        StoredWallpaperSelection(
            url: URL(fileURLWithPath: "/tmp/\(name).mp4"), bookmarkData: nil, isGenerated: true
        )
    }
}
