import Foundation
import Testing
@testable import RioVideoWallpaper

@Suite(.serialized)
struct LibraryEditorRegressionTests {
    @Test func testLibraryRootRequiresBothExplicitEnvironmentOptIns() {
        let root = "/isolated-ui-test-library"
        #expect(GeneratedAssetLibrary.uiTestingRootURL(in: [
            "VIDEO_WALLPAPER_UI_TESTING": "1",
            "VIDEO_WALLPAPER_TEST_LIBRARY_ROOT": root
        ]) == URL(fileURLWithPath: root, isDirectory: true))
        #expect(GeneratedAssetLibrary.uiTestingRootURL(in: ["VIDEO_WALLPAPER_TEST_LIBRARY_ROOT": root]) == nil)
        #expect(GeneratedAssetLibrary.uiTestingRootURL(in: ["VIDEO_WALLPAPER_UI_TESTING": "1"]) == nil)
        #expect(GeneratedAssetLibrary.uiTestingRootURL(in: [
            "VIDEO_WALLPAPER_UI_TESTING": "0",
            "VIDEO_WALLPAPER_TEST_LIBRARY_ROOT": root
        ]) == nil)
        #expect(GeneratedAssetLibrary.uiTestingRootURL(in: [
            "VIDEO_WALLPAPER_UI_TESTING": "1",
            "VIDEO_WALLPAPER_TEST_LIBRARY_ROOT": "relative-path"
        ]) == nil)
    }

    @Test func sharedAssetsSurviveDeletingOneHistoryRevision() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = try fixture.projectWithAssets(in: library)
        let firstURL = try library.save(project)
        let secondURL = try library.save(project)
        #expect(firstURL != secondURL)
        let first = try #require(library.listProjects().first { $0.projectURL == firstURL })
        try library.delete(first)
        #expect(try library.listProjects().count == 1)
        #expect(fixture.exists(project.assets.outputVideoPath))
        #expect(fixture.exists(project.assets.thumbnailPath))
        try library.delete(#require(library.listProjects().first))
        #expect(!fixture.exists(project.assets.outputVideoPath))
        #expect(!fixture.exists(project.assets.thumbnailPath))
    }

    @Test func successfulExportsAreImmutableAndCancellationOnlyRemovesStaging() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = WallpaperProject.newFieldLinesProject()
        let first = try library.beginExport(for: project)
        try Data("first".utf8).write(to: first.stagingURL)
        let firstSaved = try library.publishExport(first, project: project)
        let second = try library.beginExport(for: project)
        #expect(first.outputURL != second.outputURL)
        try Data("second".utf8).write(to: second.stagingURL)
        let secondSaved = try library.publishExport(second, project: project)
        #expect(firstSaved.projectURL != secondSaved.projectURL)
        #expect(try Data(contentsOf: first.outputURL) == Data("first".utf8))
        #expect(try Data(contentsOf: second.outputURL) == Data("second".utf8))
        let cancelled = try library.beginExport(for: project)
        try Data("unfinished".utf8).write(to: cancelled.stagingURL)
        cancelled.cancel()
        #expect(!fixture.exists(cancelled.stagingURL.path))
        #expect(try Data(contentsOf: first.outputURL) == Data("first".utf8))
        #expect(try library.listProjects().count == 2)
    }

    @Test func publicationFailureRollsBackAndNeverOverwritesExistingVideo() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var project = WallpaperProject.newFieldLinesProject()
        let lease = try library.beginExport(for: project)
        defer { lease.cancel() }
        try Data("staged".utf8).write(to: lease.stagingURL)
        project.exportSettings.loopSeconds = .infinity
        #expect(throws: Error.self) { try library.publishExport(lease, project: project) }
        #expect(fixture.exists(lease.stagingURL.path))
        #expect(!fixture.exists(lease.outputURL.path))
        #expect(try library.listProjects().isEmpty)
        try Data("successful-existing".utf8).write(to: lease.outputURL)
        project.exportSettings.loopSeconds = 10
        #expect(throws: Error.self) { try library.publishExport(lease, project: project) }
        #expect(try Data(contentsOf: lease.outputURL) == Data("successful-existing".utf8))
    }

    @Test func cancelledTaskCannotPublishACompletedStage() async throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = WallpaperProject.newFieldLinesProject()
        let lease = try library.beginExport(for: project)
        defer { lease.cancel() }
        try Data("completed-stage".utf8).write(to: lease.stagingURL)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try library.publishExport(lease, project: project)
        }
        do {
            _ = try await task.value
            Issue.record("A cancelled export must not publish.")
        } catch is CancellationError {
        }
        #expect(!fixture.exists(lease.outputURL.path))
        #expect(try library.listProjects().isEmpty)
    }

    @Test func cleanupProtectsActiveExportLeaseUntilReleased() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let lease = try library.beginExport(for: .newFieldLinesProject())
        try Data("live-stage".utf8).write(to: lease.stagingURL)
        try Data("reserved-output".utf8).write(to: lease.outputURL)
        #expect(try library.cleanupOrphanedAssets().removedAssetCount == 0)
        #expect(fixture.exists(lease.stagingURL.path))
        #expect(fixture.exists(lease.outputURL.path))
        lease.cancel()
        #expect(try library.cleanupOrphanedAssets().removedVideoCount == 1)
    }

    @Test func savedDefaultDisconnectedAndLegacyWallpaperReferencesAreProtected() throws {
        let fixture = try LibraryFixture()
        let defaults = MemoryWallpaperDefaults()
        let library = GeneratedAssetLibrary(rootURL: fixture.rootURL) {
            try GeneratedAssetLibrary.savedWallpaperURLs(defaults: defaults)
        }
        let projects = try (0..<4).map { _ in try fixture.projectWithAssets(in: library) }
        let urls = try projects.map { URL(fileURLWithPath: try #require($0.assets.outputVideoPath)) }
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: StoredWallpaperSelection(url: urls[0], bookmarkData: nil, isGenerated: true),
            perDisplaySelections: [
                "connected": StoredWallpaperSelection(url: urls[1], bookmarkData: nil, isGenerated: true),
                "disconnected": StoredWallpaperSelection(url: urls[2], bookmarkData: nil, isGenerated: true)
            ]
        )
        defaults.values[DisplayWallpaperAssignmentStore.userDefaultsKey] = try JSONEncoder().encode(assignments)
        defaults.values["FavoriteVideoURL"] = urls[3]
        let savedURL = try library.save(projects[0])
        try library.delete(#require(library.listProjects().first { $0.projectURL == savedURL }))
        _ = try library.cleanupOrphanedAssets()
        for url in urls { #expect(fixture.exists(url.path)) }
        #expect(try GeneratedAssetLibrary.savedWallpaperURLs(defaults: defaults).count == 4)
    }

    @Test func invalidSavedAssignmentsBlockCleanupBeforeAnyDeletion() throws {
        let fixture = try LibraryFixture()
        let defaults = MemoryWallpaperDefaults()
        let library = GeneratedAssetLibrary(rootURL: fixture.rootURL) {
            try GeneratedAssetLibrary.savedWallpaperURLs(defaults: defaults)
        }
        let project = try fixture.projectWithAssets(in: library)
        defaults.values[DisplayWallpaperAssignmentStore.userDefaultsKey] = Data("corrupt".utf8)
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        #expect(fixture.exists(project.assets.outputVideoPath))
        defaults.values.removeAll()
        defaults.values["FavoriteVideoBookmark"] = Data("invalid-bookmark".utf8)
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        #expect(fixture.exists(project.assets.outputVideoPath))
    }

    @Test func legacyBookmarkOnlyReferenceProtectsItsGeneratedVideo() throws {
        let fixture = try LibraryFixture()
        let defaults = MemoryWallpaperDefaults()
        let library = GeneratedAssetLibrary(rootURL: fixture.rootURL) {
            try GeneratedAssetLibrary.savedWallpaperURLs(defaults: defaults)
        }
        let project = try fixture.projectWithAssets(in: library)
        let videoURL = URL(fileURLWithPath: try #require(project.assets.outputVideoPath))
        defaults.values["FavoriteVideoBookmark"] = try videoURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #expect(try GeneratedAssetLibrary.savedWallpaperURLs(defaults: defaults).contains(videoURL))
        _ = try library.cleanupOrphanedAssets()
        #expect(fixture.exists(videoURL.path))
    }

    @Test func corruptRecordBlocksCleanupAndDeletionOfHealthyRecord() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = try fixture.projectWithAssets(in: library)
        let brokenURL = try library.save(project)
        let healthyURL = try library.save(project)
        let healthy = try #require(library.listProjects().first { $0.projectURL == healthyURL })
        try Data("{\"schemaVersion\":".utf8).write(to: brokenURL, options: .atomic)
        let scan = try library.scanProjects()
        #expect(scan.entries.count == 1)
        #expect(scan.failures.count == 1)
        #expect(throws: Error.self) { try library.listProjects() }
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        #expect(throws: Error.self) { try library.delete(healthy) }
        #expect(fixture.exists(healthyURL.path))
        #expect(fixture.exists(brokenURL.path))
        #expect(fixture.exists(project.assets.outputVideoPath))
        #expect(fixture.exists(project.assets.thumbnailPath))
    }

    @Test func unsupportedSchemaBlocksCleanup() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var project = try fixture.projectWithAssets(in: library)
        project.schemaVersion = 99
        let url = try library.projectURL(for: project)
        try WallpaperProjectFileStore.save(project, to: url)
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        #expect(fixture.exists(project.assets.outputVideoPath))
    }

    @Test func oversizedHistoryDimensionsAreRejectedBeforeSanitization() throws {
        for dimension in [\ExportSettings.width, \ExportSettings.height] {
            let fixture = try LibraryFixture()
            let library = fixture.library()
            var project = try fixture.projectWithAssets(in: library)
            project.exportSettings[keyPath: dimension] = Int.max
            let url = try library.projectURL(for: project)
            try WallpaperProjectFileStore.save(project, to: url)
            let originalData = try Data(contentsOf: url)
            #expect(throws: ExportSettingsError.self) { try WallpaperProjectFileStore.load(from: url) }
            let scan = try library.scanProjects()
            #expect(scan.entries.isEmpty)
            #expect(scan.failures.count == 1)
            #expect(scan.failures.first?.contains(ExportSettingsError.unsupportedDimensions.localizedDescription) == true)
            #expect(try Data(contentsOf: url) == originalData)
            #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
            #expect(fixture.exists(project.assets.outputVideoPath))
        }
    }

    @Test func loadingStillAllowsDocumentedLegacyLowerBoundNormalization() throws {
        var project = WallpaperProject.newFieldLinesProject()
        project.exportSettings.width = 0
        project.exportSettings.height = -10
        project.exportSettings.fps = 0
        project.exportSettings.loopSeconds = 0
        project.exportSettings.warmupLoops = -2
        let loaded = try WallpaperProjectFileStore.decode(WallpaperProjectFileStore.encode(project))
        #expect(loaded.exportSettings == project.exportSettings)
        let sanitized = WallpaperProjectSanitizer.sanitized(loaded)
        #expect(sanitized.exportSettings.width == ExportSettings.minimumWidth)
        #expect(sanitized.exportSettings.height == ExportSettings.minimumHeight)
        #expect(sanitized.exportSettings.fps == ExportSettings.minimumFPS)
        #expect(sanitized.exportSettings.loopSeconds == ExportSettings.minimumLoopSeconds)
        #expect(sanitized.exportSettings.warmupLoops == ExportSettings.minimumWarmupLoops)
    }

    @Test func nonfiniteHistoryTimingIsRejectedAtDecode() throws {
        let data = try WallpaperProjectFileStore.encode(.newFieldLinesProject())
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var settings = try #require(json["exportSettings"] as? [String: Any])
        for value in ["NaN", "Infinity", "-Infinity"] {
            settings["loopSeconds"] = value
            json["exportSettings"] = settings
            let invalidData = try JSONSerialization.data(withJSONObject: json)
            #expect(throws: Error.self) { try WallpaperProjectFileStore.decode(invalidData) }
        }
    }

    @Test func hiddenHistoryRecordsStillProtectTheirAssets() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = try fixture.projectWithAssets(in: library)
        let url = try library.save(project)
        let hiddenURL = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: hiddenURL)
        #expect(try library.cleanupOrphanedAssets().removedAssetCount == 0)
        #expect(fixture.exists(project.assets.outputVideoPath))
        #expect(fixture.exists(project.assets.thumbnailPath))
    }

    @Test func relativeAssetReferencesSurviveMovingTheEntireLibrary() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let project = try fixture.projectWithAssets(in: library)
        let url = try library.save(project)
        let stored = try WallpaperProjectFileStore.load(from: url)
        #expect(stored.assets.outputVideoPath?.hasPrefix("Videos/") == true)
        #expect(stored.assets.thumbnailPath?.hasPrefix("Thumbnails/") == true)
        let movedRoot = fixture.baseURL.appendingPathComponent("Moved")
        try FileManager.default.moveItem(at: fixture.rootURL, to: movedRoot)
        let moved = GeneratedAssetLibrary(rootURL: movedRoot, protectedWallpaperURLs: { [] })
        let entry = try #require(moved.listProjects().first)
        let loaded = try moved.load(entry)
        #expect(loaded.assets.outputVideoPath?.hasPrefix(movedRoot.path + "/Videos/") == true)
        #expect(fixture.exists(loaded.assets.outputVideoPath))
        #expect(fixture.exists(loaded.assets.thumbnailPath))
        #expect(try moved.cleanupOrphanedAssets().removedAssetCount == 0)
    }

    @Test func legacyAbsolutePathsMigrateOnlyWhenOwnedAssetsCanBeResolved() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var project = WallpaperProject.newFieldLinesProject()
        let url = try library.projectURL(for: project)
        let legacyVideo = library.videosDirectoryURL.appendingPathComponent(project.id.uuidString + ".mp4")
        let legacyThumbnail = library.thumbnailsDirectoryURL.appendingPathComponent(project.id.uuidString + ".png")
        try Data("legacy-video".utf8).write(to: legacyVideo)
        try Data("legacy-thumbnail".utf8).write(to: legacyThumbnail)
        project.assets.outputVideoPath = legacyVideo.path
        project.assets.thumbnailPath = legacyThumbnail.path
        try WallpaperProjectFileStore.save(project, to: url)
        let movedRoot = fixture.baseURL.appendingPathComponent("Moved")
        try FileManager.default.moveItem(at: fixture.rootURL, to: movedRoot)
        let moved = GeneratedAssetLibrary(rootURL: movedRoot, protectedWallpaperURLs: { [] })
        let entry = try #require(moved.listProjects().first)
        let migrated = try WallpaperProjectFileStore.load(from: entry.projectURL)
        #expect(migrated.assets.outputVideoPath == "Videos/\(project.id.uuidString).mp4")
        #expect(migrated.assets.thumbnailPath == "Thumbnails/\(project.id.uuidString).png")
        #expect(try moved.cleanupOrphanedAssets().removedAssetCount == 0)

        try FileManager.default.removeItem(at: movedRoot.appendingPathComponent("Videos/\(project.id.uuidString).mp4"))
        try WallpaperProjectFileStore.save(project, to: entry.projectURL)
        #expect(throws: Error.self) { try moved.cleanupOrphanedAssets() }
        #expect(fixture.exists(movedRoot.appendingPathComponent("Thumbnails/\(project.id.uuidString).png").path))
    }

    @Test func traversalAndExternalDirectorySymlinksAreRejected() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var project = WallpaperProject.newFieldLinesProject()
        let url = try library.projectURL(for: project)
        project.assets.outputVideoPath = "Videos/../outside.mp4"
        try WallpaperProjectFileStore.save(project, to: url)
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        try FileManager.default.removeItem(at: url)
        let outside = fixture.baseURL.appendingPathComponent("Outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("keep.mp4")
        try Data("keep".utf8).write(to: sentinel)
        try FileManager.default.removeItem(at: library.videosDirectoryURL)
        try FileManager.default.createSymbolicLink(at: library.videosDirectoryURL, withDestinationURL: outside)
        #expect(throws: Error.self) { try library.cleanupOrphanedAssets() }
        #expect(fixture.exists(sentinel.path))
    }

    @Test func intentIsProvenanceAndDoesNotOverwriteManualParameters() throws {
        var project = WallpaperProjectSanitizer.sanitized(.newFieldLinesProject())
        project.visualIntent = PromptInterpreter.interpret("red lines", seed: project.seed)
        guard case .fieldLines(var parameters) = project.renderParameters else {
            Issue.record("Expected field lines.")
            return
        }
        parameters.hueBaseDegrees = 210
        parameters.speed = 0.9
        project.renderParameters = .fieldLines(parameters)
        project.assets.outputVideoPath = "/saved-video.mp4"
        let reloaded = try WallpaperProjectFileStore.decode(WallpaperProjectFileStore.encode(project))
        let result = WallpaperProjectSanitizer.sanitize(reloaded)
        #expect(result.project.renderParameters == project.renderParameters)
        #expect(result.project.exportSettings == project.exportSettings)
        #expect(result.project.assets.outputVideoPath == project.assets.outputVideoPath)
        #expect(!result.invalidatedOutputVideo)
    }

    @Test func editingSnapshotsAccumulateThumbnailDirtyAndDoNotAcceptStaleCompletion() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var project = WallpaperProject.newFieldLinesProject()
        var state = GenerativeEditorRevisionState()
        try state.recordEdit(project, library: library, regenerateThumbnail: true)
        let first = try #require(state.pendingSave)
        project.seed &+= 1
        try state.recordEdit(project, library: library, regenerateThumbnail: false)
        let second = try #require(state.pendingSave)
        #expect(second.regenerateThumbnail)
        #expect(first.project.seed != second.project.seed)
        #expect(!state.matches(first, project: project, library: library))
        state.didSave(first)
        #expect(state.pendingSave?.revision == second.revision)
        let result = try GenerativeSnapshotPersistence.saveRecord(second)
        _ = try library.attachThumbnail(Data("thumbnail".utf8), to: result)
        state.didSave(second)
        #expect(state.pendingSave == nil)
        #expect(try library.listProjects().count == 1)
        #expect(try library.loadProject(at: result.projectURL).seed == project.seed)
        let otherRoot = GeneratedAssetLibrary(rootURL: fixture.baseURL.appendingPathComponent("Other"), protectedWallpaperURLs: { [] })
        #expect(!state.matches(second, project: project, library: otherRoot))
        state.beginProject()
        #expect(!state.matches(second, project: project, library: library))
    }

    @Test func thumbnailFailureDoesNotLoseTheEditableSnapshot() async throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var state = GenerativeEditorRevisionState()
        let project = WallpaperProject.newFieldLinesProject()
        try state.recordEdit(project, library: library, regenerateThumbnail: true)
        let snapshot = try #require(state.pendingSave)
        let result = try GenerativeSnapshotPersistence.saveRecord(snapshot)
        do {
            _ = try await GenerativeSnapshotPersistence.renderThumbnailData(for: project) { _ in
                throw CocoaError(.fileWriteUnknown)
            }
            Issue.record("Expected thumbnail failure.")
        } catch {
            #expect(error is CocoaError)
            #expect(!GenerativeSnapshotPersistence.thumbnailErrorMessage(error).isEmpty)
        }
        #expect(try library.listProjects().count == 1)
        #expect(try library.loadProject(at: result.projectURL).renderParameters == project.renderParameters)
        state.didSave(snapshot)
        #expect(state.pendingSave == nil)
    }

    @Test func completionPersistsSourceProjectInSourceRootAfterSwitchingProjects() throws {
        let fixture = try LibraryFixture()
        let sourceLibrary = fixture.library()
        let otherLibrary = GeneratedAssetLibrary(rootURL: fixture.baseURL.appendingPathComponent("Other"), protectedWallpaperURLs: { [] })
        var state = GenerativeEditorRevisionState()
        let source = WallpaperProject.newFieldLinesProject()
        let snapshot = try state.snapshot(source, library: sourceLibrary)
        let lease = try sourceLibrary.beginExport(for: snapshot.project)
        defer { lease.cancel() }
        let other = WallpaperProject.newProject(rendererFamily: .orbital)
        state.beginProject()
        try Data("source-result".utf8).write(to: lease.stagingURL)
        #expect(throws: Error.self) { try otherLibrary.publishExport(lease, project: source) }
        #expect(throws: Error.self) { try sourceLibrary.publishExport(lease, project: other) }
        let saved = try snapshot.library.publishExport(lease, project: snapshot.project)
        #expect(saved.project.id == source.id)
        #expect(!state.matches(snapshot, project: other, library: otherLibrary))
        #expect(other.assets.outputVideoPath == nil)
        #expect(try sourceLibrary.listProjects().count == 1)
        #expect(try otherLibrary.listProjects().isEmpty)
    }

    @Test func failedSaveRemainsInRetainedDraftForTheNextEditorLifetime() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        let draft = GenerativeEditorDraft()
        var project = WallpaperProject.newFieldLinesProject()
        project.exportSettings.loopSeconds = .infinity
        try draft.revisionState.recordEdit(project, library: library, regenerateThumbnail: false)
        let pending = try #require(draft.revisionState.pendingSave)
        #expect(throws: Error.self) {
            try GenerativeSnapshotPersistence.saveRecord(pending)
        }
        draft.project = project
        draft.library = library
        var nextLifetime = draft.revisionState
        #expect(nextLifetime.pendingSave?.revision == pending.revision)
        project.exportSettings.loopSeconds = 10
        try nextLifetime.recordEdit(project, library: library, regenerateThumbnail: false)
        let retry = try #require(nextLifetime.pendingSave)
        _ = try GenerativeSnapshotPersistence.saveRecord(retry)
        nextLifetime.didSave(retry)
        #expect(nextLifetime.pendingSave == nil)
        #expect(try library.listProjects().count == 1)
    }

    @Test @MainActor func thumbnailRenderingRunsOffTheMainThread() async throws {
        let data = try await GenerativeSnapshotPersistence.renderThumbnailData(for: .newFieldLinesProject()) { _ in
            Data((Thread.isMainThread ? "main" : "background").utf8)
        }
        #expect(data == Data("background".utf8))
    }

    @Test func cancellationDiscardsLateThumbnailData() async throws {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let task = Task {
            try await GenerativeSnapshotPersistence.renderThumbnailData(for: .newFieldLinesProject()) { _ in
                started.signal()
                release.wait()
                return Data("late".utf8)
            }
        }
        await Task.detached { started.wait() }.value
        task.cancel()
        release.signal()
        do {
            _ = try await task.value
            Issue.record("A cancelled thumbnail task must discard its result.")
        } catch is CancellationError {
        }
    }

    @Test func lateThumbnailsCannotResurrectDeletedOrOverwriteChangedHistory() throws {
        let fixture = try LibraryFixture()
        let library = fixture.library()
        var state = GenerativeEditorRevisionState()
        let project = WallpaperProject.newFieldLinesProject()
        try state.recordEdit(project, library: library, regenerateThumbnail: true)
        let saved = try GenerativeSnapshotPersistence.saveRecord(#require(state.pendingSave))
        var changed = saved.project
        changed.seed &+= 1
        try library.save(changed, to: saved.projectURL)
        #expect(try library.attachThumbnail(Data("stale".utf8), to: saved) == nil)
        try library.delete(#require(library.listProjects().first))
        #expect(try library.attachThumbnail(Data("deleted".utf8), to: saved) == nil)
        #expect(try library.listProjects().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: library.thumbnailsDirectoryURL.path).isEmpty)
    }
}

private final class MemoryWallpaperDefaults: UserDefaults {
    var values: [String: Any] = [:]
    override func object(forKey defaultName: String) -> Any? { values[defaultName] }
    override func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    override func url(forKey defaultName: String) -> URL? { values[defaultName] as? URL }
}

private final class LibraryFixture {
    let baseURL: URL
    var rootURL: URL { baseURL.appendingPathComponent("Library") }

    init() throws {
        let directory = ProcessInfo.processInfo.environment["RIO_TEST_ARTIFACTS"] ?? FileManager.default.currentDirectoryPath
        baseURL = URL(fileURLWithPath: directory, isDirectory: true)
            .appendingPathComponent("LibraryEditorRegression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func library() -> GeneratedAssetLibrary {
        GeneratedAssetLibrary(rootURL: rootURL, protectedWallpaperURLs: { [] })
    }

    func projectWithAssets(in library: GeneratedAssetLibrary) throws -> WallpaperProject {
        var project = WallpaperProject.newFieldLinesProject()
        let video = try library.videoURL(for: project)
        let thumbnail = try library.thumbnailURL(for: project)
        try Data("video".utf8).write(to: video)
        try Data("thumbnail".utf8).write(to: thumbnail)
        project.assets.outputVideoPath = video.path
        project.assets.thumbnailPath = thumbnail.path
        return project
    }

    func exists(_ path: String?) -> Bool {
        path.map { FileManager.default.fileExists(atPath: $0) } ?? false
    }

    deinit { try? FileManager.default.removeItem(at: baseURL) }
}
