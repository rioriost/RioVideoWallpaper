//
//  GeneratedAssetLibrary.swift
//  RioVideoWallpaper
//

import Foundation

struct ProjectLibraryEntry: Equatable, Identifiable {
    var id: String
    var projectID: UUID
    var title: String
    var updatedAt: Date
    var rendererFamily: RendererFamily
    var projectURL: URL
    var outputVideoPath: String?
    var thumbnailPath: String?
    var promptPreview: String?
}

struct GeneratedAssetCleanupReport: Equatable {
    var removedVideoCount: Int
    var removedThumbnailCount: Int

    var removedAssetCount: Int { removedVideoCount + removedThumbnailCount }
}

struct ProjectLibraryScan {
    var entries: [ProjectLibraryEntry]
    var failures: [String]

    func requireComplete() throws {
        guard failures.isEmpty else {
            throw GeneratedAssetLibraryError.incompleteScan(failures)
        }
    }
}

enum GeneratedAssetLibraryError: LocalizedError {
    case incompleteScan([String])
    case invalidAssetReference(String)
    case unresolvedLegacyAsset(String)
    case invalidProjectLocation
    case invalidExportLease
    case destinationExists
    case inaccessibleRoot
    case unreadableWallpaperAssignments

    var errorDescription: String? {
        switch self {
        case .incompleteScan(let failures):
            return AppLocalization.string("No assets were removed because some history records could not be read:") + "\n" + failures.joined(separator: "\n")
        case .invalidAssetReference(let path):
            return String(format: AppLocalization.string("Invalid generated asset reference: %@"), path)
        case .unresolvedLegacyAsset(let path):
            return String(format: AppLocalization.string("A moved library asset could not be resolved: %@. Restore the missing file before cleaning history."), path)
        case .invalidProjectLocation:
            return AppLocalization.string("The history record does not belong to this library.")
        case .invalidExportLease:
            return AppLocalization.string("This export is no longer active.")
        case .destinationExists:
            return AppLocalization.string("The export destination already exists. The existing video was not changed.")
        case .inaccessibleRoot:
            return AppLocalization.string("The selected history folder is unavailable. Select it again in Settings.")
        case .unreadableWallpaperAssignments:
            return AppLocalization.string("Saved wallpaper references could not be read. No generated assets were removed.")
        }
    }
}

private final class GeneratedAssetAccessRegistry {
    static let shared = GeneratedAssetAccessRegistry()
    let lock = NSRecursiveLock()
    var leases: [UUID: Set<URL>] = [:]
}

final class GeneratedExportLease {
    let library: GeneratedAssetLibrary
    let stagingURL: URL
    let outputURL: URL
    let projectID: UUID
    fileprivate let id = UUID()
    fileprivate var isActive = true
    private var stopAccessing: (() -> Void)?

    fileprivate init(library: GeneratedAssetLibrary, projectID: UUID, stagingURL: URL, outputURL: URL, stopAccessing: (() -> Void)?) {
        self.library = library
        self.projectID = projectID
        self.stagingURL = stagingURL
        self.outputURL = outputURL
        self.stopAccessing = stopAccessing
        GeneratedAssetAccessRegistry.shared.leases[id] = [stagingURL.canonicalFileURL, outputURL.canonicalFileURL]
    }

    func cancel() {
        let registry = GeneratedAssetAccessRegistry.shared
        registry.lock.lock()
        defer { registry.lock.unlock() }
        guard isActive else { return }
        try? FileManager.default.removeItem(at: stagingURL)
        finish()
    }

    fileprivate func finish() {
        isActive = false
        GeneratedAssetAccessRegistry.shared.leases.removeValue(forKey: id)
        stopAccessing?()
        stopAccessing = nil
    }

    deinit { cancel() }
}

struct SavedGeneratedProject {
    var project: WallpaperProject
    var projectURL: URL
}

struct GeneratedAssetLibrary {
    static let rootDidChangeNotification = Notification.Name("GeneratedAssetLibraryRootDidChange")
    private static let customRootPathKey = "GeneratedAssetLibrary.customRootPath"
    private static let customRootBookmarkKey = "GeneratedAssetLibrary.customRootBookmark"

    private let explicitRootURL: URL?
    private let requiresSecurityScope: Bool
    private let protectedWallpaperURLs: () throws -> [URL]

    init(
        rootURL: URL? = nil,
        protectedWallpaperURLs: @escaping () throws -> [URL] = { try savedWallpaperURLs() }
    ) {
        explicitRootURL = rootURL ?? Self.uiTestingRootURL(in: ProcessInfo.processInfo.environment)
        requiresSecurityScope = false
        self.protectedWallpaperURLs = protectedWallpaperURLs
    }

    private init(rootURL: URL, requiresSecurityScope: Bool, protectedWallpaperURLs: @escaping () throws -> [URL]) {
        explicitRootURL = rootURL
        self.requiresSecurityScope = requiresSecurityScope
        self.protectedWallpaperURLs = protectedWallpaperURLs
    }

    var rootURL: URL { explicitRootURL ?? Self.currentRootURL }
    var projectsDirectoryURL: URL { rootURL.appendingPathComponent("Projects", isDirectory: true) }
    var videosDirectoryURL: URL { rootURL.appendingPathComponent("Videos", isDirectory: true) }
    var thumbnailsDirectoryURL: URL { rootURL.appendingPathComponent("Thumbnails", isDirectory: true) }

    func pinned() throws -> GeneratedAssetLibrary {
        if explicitRootURL != nil { return self }
        let url: URL
        if Self.usesCustomRootURL {
            guard let resolvedURL = try Self.resolveCustomRootURL() else {
                throw GeneratedAssetLibraryError.inaccessibleRoot
            }
            url = resolvedURL
        } else {
            url = Self.defaultRootURL()
        }
        return GeneratedAssetLibrary(
            rootURL: url,
            requiresSecurityScope: Self.usesCustomRootURL,
            protectedWallpaperURLs: protectedWallpaperURLs
        )
    }

    @discardableResult
    func withRootAccess<T>(_ work: () throws -> T) throws -> T {
        let registry = GeneratedAssetAccessRegistry.shared
        registry.lock.lock()
        defer { registry.lock.unlock() }
        let stopAccessing = try startAccessingRootIfNeeded()
        defer { stopAccessing?() }
        return try work()
    }

    func startAccessingRootIfNeeded() throws -> (() -> Void)? {
        let library = try pinned()
        guard library.requiresSecurityScope else { return nil }
        let url = library.rootURL
        guard url.startAccessingSecurityScopedResource() else {
            throw GeneratedAssetLibraryError.inaccessibleRoot
        }
        return { url.stopAccessingSecurityScopedResource() }
    }

    func save(_ project: WallpaperProject) throws -> URL {
        let library = try pinned()
        return try library.withRootAccess {
            let url = try library.projectURL(for: project)
            try library.save(project, to: url)
            return url
        }
    }

    func save(_ project: WallpaperProject, to url: URL) throws {
        if explicitRootURL == nil { return try pinned().save(project, to: url) }
        try withRootAccess {
            guard url.isDescendant(of: projectsDirectoryURL),
                  url.pathExtension == WallpaperProjectFileStore.fileExtension else {
                throw GeneratedAssetLibraryError.invalidProjectLocation
            }
            try WallpaperProjectFileStore.save(projectForStorage(project), to: url)
        }
    }

    func projectURL(for project: WallpaperProject, date: Date = Date()) throws -> URL {
        if explicitRootURL == nil { return try pinned().projectURL(for: project, date: date) }
        return try withRootAccess {
            try ensureDirectories()
            return projectsDirectoryURL.appendingPathComponent(Self.projectFileName(for: project, date: date))
        }
    }

    func videoURL(for project: WallpaperProject, fileExtension: String = "mp4") throws -> URL {
        if explicitRootURL == nil { return try pinned().videoURL(for: project, fileExtension: fileExtension) }
        return try withRootAccess {
            try ensureDirectories()
            return try assetURL(in: videosDirectoryURL, name: "\(project.id.uuidString)-\(UUID().uuidString)", extension: fileExtension)
        }
    }

    func thumbnailURL(for project: WallpaperProject, fileExtension: String = "png") throws -> URL {
        if explicitRootURL == nil { return try pinned().thumbnailURL(for: project, fileExtension: fileExtension) }
        return try withRootAccess {
            try ensureDirectories()
            return try assetURL(in: thumbnailsDirectoryURL, name: project.id.uuidString, extension: fileExtension)
        }
    }

    func thumbnailURL(forProjectURL projectURL: URL, fileExtension: String = "png") throws -> URL {
        if explicitRootURL == nil { return try pinned().thumbnailURL(forProjectURL: projectURL, fileExtension: fileExtension) }
        return try withRootAccess {
            try ensureDirectories()
            return try assetURL(
                in: thumbnailsDirectoryURL,
                name: projectURL.deletingPathExtension().lastPathComponent,
                extension: fileExtension
            )
        }
    }

    func beginExport(for project: WallpaperProject) throws -> GeneratedExportLease {
        let library = try pinned()
        return try library.withRootAccess {
            let outputURL = try library.videoURL(for: project)
            let stagingDirectory = library.rootURL.appendingPathComponent(".Staging", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            let stagingURL = stagingDirectory.appendingPathComponent(outputURL.lastPathComponent)
            let stopAccessing = try library.startAccessingRootIfNeeded()
            return GeneratedExportLease(library: library, projectID: project.id, stagingURL: stagingURL, outputURL: outputURL, stopAccessing: stopAccessing)
        }
    }

    func publishExport(_ lease: GeneratedExportLease, project: WallpaperProject) throws -> SavedGeneratedProject {
        if explicitRootURL == nil { return try pinned().publishExport(lease, project: project) }
        return try withRootAccess {
            try Task.checkCancellation()
            guard lease.isActive, lease.projectID == project.id,
                  lease.library.rootURL.canonicalFileURL == rootURL.canonicalFileURL else {
                throw GeneratedAssetLibraryError.invalidExportLease
            }
            guard !FileManager.default.fileExists(atPath: lease.outputURL.path) else {
                throw GeneratedAssetLibraryError.destinationExists
            }
            var publishedProject = project
            publishedProject.assets.outputVideoPath = lease.outputURL.path
            publishedProject.updatedAt = Date()
            try FileManager.default.moveItem(at: lease.stagingURL, to: lease.outputURL)
            do {
                let projectURL = try save(publishedProject)
                lease.finish()
                return SavedGeneratedProject(project: publishedProject, projectURL: projectURL)
            } catch {
                try? FileManager.default.moveItem(at: lease.outputURL, to: lease.stagingURL)
                throw error
            }
        }
    }

    func attachThumbnail(_ data: Data, to saved: SavedGeneratedProject) throws -> SavedGeneratedProject? {
        if explicitRootURL == nil { return try pinned().attachThumbnail(data, to: saved) }
        return try withRootAccess {
            try Task.checkCancellation()
            guard saved.projectURL.isDescendant(of: projectsDirectoryURL) else {
                throw GeneratedAssetLibraryError.invalidProjectLocation
            }
            guard FileManager.default.fileExists(atPath: saved.projectURL.path) else { return nil }
            var current = try loadProject(at: saved.projectURL)
            guard current.id == saved.project.id, current.seed == saved.project.seed,
                  current.renderParameters == saved.project.renderParameters,
                  current.exportSettings == saved.project.exportSettings else { return nil }
            if current.assets.thumbnailPath != nil {
                return SavedGeneratedProject(project: current, projectURL: saved.projectURL)
            }
            let url = try assetURL(
                in: thumbnailsDirectoryURL,
                name: "\(current.id.uuidString)-\(UUID().uuidString)",
                extension: "png"
            )
            try data.write(to: url, options: .withoutOverwriting)
            do {
                current.assets.thumbnailPath = url.path
                try save(current, to: saved.projectURL)
            } catch {
                try? FileManager.default.removeItem(at: url)
                throw error
            }
            return SavedGeneratedProject(project: current, projectURL: saved.projectURL)
        }
    }

    func containsGeneratedVideo(_ url: URL) -> Bool { url.isDescendant(of: videosDirectoryURL) }

    func load(_ entry: ProjectLibraryEntry) throws -> WallpaperProject {
        try loadProject(at: entry.projectURL)
    }

    func loadProject(at url: URL) throws -> WallpaperProject {
        if explicitRootURL == nil { return try pinned().loadProject(at: url) }
        return try withRootAccess {
            let storedProject = try WallpaperProjectFileStore.load(from: url)
            let project = try resolvedProject(storedProject)
            if url.isDescendant(of: projectsDirectoryURL) {
                let migrated = try projectForStorage(project)
                if migrated != storedProject {
                    try WallpaperProjectFileStore.save(migrated, to: url)
                }
            }
            return project
        }
    }

    func delete(_ entry: ProjectLibraryEntry) throws {
        if explicitRootURL == nil { return try pinned().delete(entry) }
        try withRootAccess {
            let scan = try scanProjects()
            try scan.requireComplete()
            guard entry.projectURL.isDescendant(of: projectsDirectoryURL),
                  let storedEntry = scan.entries.first(where: { $0.id == entry.id }) else {
                throw GeneratedAssetLibraryError.invalidProjectLocation
            }
            let remaining = scan.entries.filter { $0.id != entry.id }
            let references = try referencedAssets(in: remaining)
            try FileManager.default.removeItem(at: storedEntry.projectURL)
            for path in [storedEntry.outputVideoPath, storedEntry.thumbnailPath].compactMap({ $0 }) {
                let url = URL(fileURLWithPath: path)
                guard url.isDescendant(of: videosDirectoryURL) || url.isDescendant(of: thumbnailsDirectoryURL),
                      !references.contains(url.canonicalFileURL) else { continue }
                try removeRegularFileIfExists(at: url)
            }
        }
    }

    func cleanupOrphanedAssets() throws -> GeneratedAssetCleanupReport {
        if explicitRootURL == nil { return try pinned().cleanupOrphanedAssets() }
        return try withRootAccess {
            let scan = try scanProjects()
            try scan.requireComplete()
            let references = try referencedAssets(in: scan.entries)
            return GeneratedAssetCleanupReport(
                removedVideoCount: try removeUnreferencedFiles(under: videosDirectoryURL, referencedURLs: references),
                removedThumbnailCount: try removeUnreferencedFiles(under: thumbnailsDirectoryURL, referencedURLs: references)
            )
        }
    }

    func scanProjects() throws -> ProjectLibraryScan {
        if explicitRootURL == nil { return try pinned().scanProjects() }
        return try withRootAccess {
            try ensureDirectories()
            let urls = try FileManager.default.contentsOfDirectory(
                at: projectsDirectoryURL,
                includingPropertiesForKeys: nil,
                options: []
            )
            var entries: [ProjectLibraryEntry] = []
            var failures: [String] = []
            for url in urls where url.pathExtension == WallpaperProjectFileStore.fileExtension {
                do {
                    entries.append(ProjectLibraryEntry(project: try loadProject(at: url), projectURL: url))
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            entries.sort {
                $0.updatedAt == $1.updatedAt
                    ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    : $0.updatedAt > $1.updatedAt
            }
            return ProjectLibraryScan(entries: entries, failures: failures)
        }
    }

    func listProjects() throws -> [ProjectLibraryEntry] {
        let scan = try scanProjects()
        try scan.requireComplete()
        return scan.entries
    }

    private func referencedAssets(in entries: [ProjectLibraryEntry]) throws -> Set<URL> {
        var references = Set(entries.flatMap { [$0.outputVideoPath, $0.thumbnailPath].compactMap { $0 } }
            .map { URL(fileURLWithPath: $0).canonicalFileURL })
        for url in try protectedWallpaperURLs() {
            references.insert(url.canonicalFileURL)
            // A stored display bookmark may still contain the pre-move library path.
            if url.deletingLastPathComponent().lastPathComponent == "Videos" {
                references.insert(videosDirectoryURL.appendingPathComponent(url.lastPathComponent).canonicalFileURL)
            }
        }
        for leasedURLs in GeneratedAssetAccessRegistry.shared.leases.values {
            references.formUnion(leasedURLs)
        }
        return references
    }

    private func projectForStorage(_ project: WallpaperProject) throws -> WallpaperProject {
        var stored = try resolvedProject(project)
        stored.rendererFamily = stored.renderParameters.rendererFamily
        stored.visualIntent?.rendererFamily = stored.rendererFamily
        var hasOwnedAsset = false
        func storedPath(_ path: String?, directory: URL) -> String? {
            guard let path else { return nil }
            let url = URL(fileURLWithPath: path)
            guard url.isDescendant(of: directory) else { return path }
            hasOwnedAsset = true
            return "\(directory.lastPathComponent)/\(url.lastPathComponent)"
        }
        stored.assets.outputVideoPath = storedPath(stored.assets.outputVideoPath, directory: videosDirectoryURL)
        stored.assets.thumbnailPath = storedPath(stored.assets.thumbnailPath, directory: thumbnailsDirectoryURL)
        stored.assets.libraryRootPath = hasOwnedAsset ? rootURL.standardizedFileURL.path : nil
        return stored
    }

    private func resolvedProject(_ project: WallpaperProject) throws -> WallpaperProject {
        var resolved = project
        resolved.assets.outputVideoPath = try resolvedAssetPath(project.assets.outputVideoPath, directory: videosDirectoryURL, project: project)
        resolved.assets.thumbnailPath = try resolvedAssetPath(project.assets.thumbnailPath, directory: thumbnailsDirectoryURL, project: project)
        return resolved
    }

    private func resolvedAssetPath(_ path: String?, directory: URL, project: WallpaperProject) throws -> String? {
        guard let path else { return nil }
        if !path.hasPrefix("/") {
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count == 2, components[0] == directory.lastPathComponent,
                  components[1] != ".", components[1] != "..", !components[1].isEmpty else {
                throw GeneratedAssetLibraryError.invalidAssetReference(path)
            }
            let url = directory.appendingPathComponent(String(components[1]))
            guard url.isDescendant(of: directory) else {
                throw GeneratedAssetLibraryError.invalidAssetReference(path)
            }
            return url.path
        }
        let original = URL(fileURLWithPath: path)
        if original.isDescendant(of: directory) { return original.path }
        let oldDirectory = original.deletingLastPathComponent()
        let name = original.deletingPathExtension().lastPathComponent
        let knownRoot = project.assets.libraryRootPath.map {
            oldDirectory.standardizedFileURL == URL(fileURLWithPath: $0).appendingPathComponent(directory.lastPathComponent).standardizedFileURL
        } ?? false
        let legacyName = name == project.id.uuidString ||
            name.hasPrefix(project.id.uuidString + "-") ||
            (name.hasPrefix("RioVideoWallpaper-") && name.hasSuffix("-" + project.id.uuidString))
        guard knownRoot || (oldDirectory.lastPathComponent == directory.lastPathComponent && legacyName) else {
            return original.path
        }
        let relocated = directory.appendingPathComponent(original.lastPathComponent)
        guard relocated.isDescendant(of: directory),
              FileManager.default.fileExists(atPath: relocated.path) else {
            throw GeneratedAssetLibraryError.unresolvedLegacyAsset(path)
        }
        return relocated.path
    }

    private func ensureDirectories() throws {
        for directory in [projectsDirectoryURL, videosDirectoryURL, thumbnailsDirectoryURL] {
            guard directory.isDescendant(of: rootURL) else {
                throw GeneratedAssetLibraryError.invalidAssetReference(directory.path)
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func assetURL(in directory: URL, name: String, extension fileExtension: String) throws -> URL {
        let normalizedExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !normalizedExtension.contains("/"), !normalizedExtension.contains("\\") else {
            throw GeneratedAssetLibraryError.invalidAssetReference(fileExtension)
        }
        let url = directory.appendingPathComponent(name)
        return normalizedExtension.isEmpty ? url : url.appendingPathExtension(normalizedExtension)
    }

    private func removeUnreferencedFiles(under directory: URL, referencedURLs: Set<URL>) throws -> Int {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
        var count = 0
        for url in urls where !referencedURLs.contains(url.canonicalFileURL) {
            if try removeRegularFileIfExists(at: url) { count += 1 }
        }
        return count
    }

    @discardableResult
    private func removeRegularFileIfExists(at url: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { return false }
        try FileManager.default.removeItem(at: url)
        return true
    }

    static func savedWallpaperURLs(defaults: UserDefaults = .standard) throws -> [URL] {
        var urls: [URL] = []
        func includeBookmark(_ data: Data?) throws {
            guard let data else { return }
            var stale = false
            do {
                // Reference discovery needs the path, not a lease to open the video.
                urls.append(try URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale))
            } catch {
                throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
            }
        }
        if let value = defaults.object(forKey: DisplayWallpaperAssignmentStore.userDefaultsKey) {
            guard value is Data else {
                throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
            }
            let assignments: StoredDisplayWallpaperAssignments
            do {
                guard let stored = try DisplayWallpaperAssignmentStore(defaults: defaults).loadChecked() else {
                    throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
                }
                assignments = stored
            } catch {
                throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
            }
            for selection in assignments.allSelections() {
                urls.append(selection.url)
                try includeBookmark(selection.bookmarkData)
            }
        }
        if defaults.object(forKey: "FavoriteVideoURL") != nil {
            guard let url = defaults.url(forKey: "FavoriteVideoURL"), url.isFileURL else {
                throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
            }
            urls.append(url)
        }
        if defaults.object(forKey: "FavoriteVideoBookmark") != nil,
           defaults.data(forKey: "FavoriteVideoBookmark") == nil {
            throw GeneratedAssetLibraryError.unreadableWallpaperAssignments
        }
        try includeBookmark(defaults.data(forKey: "FavoriteVideoBookmark"))
        return urls
    }

    static var currentRootURL: URL {
        if let root = uiTestingRootURL(in: ProcessInfo.processInfo.environment) { return root }
        if let url = try? resolveCustomRootURL() { return url }
        if let path = UserDefaults.standard.string(forKey: customRootPathKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return defaultRootURL()
    }

    static var usesCustomRootURL: Bool {
        if uiTestingRootURL(in: ProcessInfo.processInfo.environment) != nil { return false }
        return UserDefaults.standard.string(forKey: customRootPathKey)?.isEmpty == false ||
            UserDefaults.standard.data(forKey: customRootBookmarkKey) != nil
    }

    static func uiTestingRootURL(in environment: [String: String]) -> URL? {
        guard environment["VIDEO_WALLPAPER_UI_TESTING"] == "1",
              let path = environment["VIDEO_WALLPAPER_TEST_LIBRARY_ROOT"],
              path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func setCustomRootURL(_ url: URL) throws {
        let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: customRootBookmarkKey)
        UserDefaults.standard.set(url.standardizedFileURL.path, forKey: customRootPathKey)
        NotificationCenter.default.post(name: rootDidChangeNotification, object: nil)
    }

    static func resetRootURL() {
        UserDefaults.standard.removeObject(forKey: customRootBookmarkKey)
        UserDefaults.standard.removeObject(forKey: customRootPathKey)
        NotificationCenter.default.post(name: rootDidChangeNotification, object: nil)
    }

    static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("RioVideoWallpaper/Generated", isDirectory: true)
    }

    private static func resolveCustomRootURL() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: customRootBookmarkKey) else { return nil }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
        // Refreshing bookmarks requires an active scope; never silently replace a failed bookmark.
        if stale {
            guard url.startAccessingSecurityScopedResource() else { throw GeneratedAssetLibraryError.inaccessibleRoot }
            defer { url.stopAccessingSecurityScopedResource() }
            let refreshed = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(refreshed, forKey: customRootBookmarkKey)
            UserDefaults.standard.set(url.standardizedFileURL.path, forKey: customRootPathKey)
        }
        return url
    }

    static func exportFileName(for project: WallpaperProject, date: Date = Date(), fileExtension: String = "mp4") -> String {
        let family = project.renderParameters.rendererFamily.displayName
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "RioVideoWallpaper-\(family)-\(formatter.string(from: date))"
        let suffix = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return suffix.isEmpty ? name : "\(name).\(suffix)"
    }

    static func projectFileName(for project: WallpaperProject, date: Date = Date()) -> String {
        "\(exportFileName(for: project, date: date, fileExtension: ""))-\(project.id.uuidString)-\(UUID().uuidString).\(WallpaperProjectFileStore.fileExtension)"
    }
}

private extension URL {
    var canonicalFileURL: URL { standardizedFileURL.resolvingSymlinksInPath() }

    func isDescendant(of directoryURL: URL) -> Bool {
        canonicalFileURL.path.hasPrefix(directoryURL.canonicalFileURL.path + "/")
    }
}

private extension ProjectLibraryEntry {
    init(project: WallpaperProject, projectURL: URL) {
        id = projectURL.standardizedFileURL.path
        projectID = project.id
        title = project.renderParameters.rendererFamily.displayName
        updatedAt = project.updatedAt
        rendererFamily = project.renderParameters.rendererFamily
        self.projectURL = projectURL
        outputVideoPath = project.assets.outputVideoPath
        thumbnailPath = project.assets.thumbnailPath
        promptPreview = project.promptHistory.last?.prompt
    }
}
