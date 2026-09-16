//
//  DisplayWallpaperAssignment.swift
//  RioVideoWallpaper
//

import AppKit
import Foundation
import os

struct DisplayVideoAssignment: Equatable {
    var defaultVideoURL: URL
    var videoURLByDisplayID: [String: URL]

    func videoURL(for screen: NSScreen) -> URL {
        videoURL(forDisplayID: DisplayIdentifier.id(for: screen))
    }

    func videoURL(forDisplayID displayID: String) -> URL {
        videoURLByDisplayID[displayID] ?? defaultVideoURL
    }
}

enum DisplayIdentifier {
    static func id(for screen: NSScreen) -> String {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(screenNumber.uint32Value)"
        }

        let frame = screen.frame
        return "frame-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(Int(frame.width))-\(Int(frame.height))"
    }

    static func label(for screen: NSScreen, index: Int) -> String {
        let size = screen.frame.size
        let role = screen == NSScreen.main ? "Main" : "Display"
        return "\(role) \(index + 1) (\(Int(size.width)) x \(Int(size.height)))"
    }
}

struct StoredWallpaperSelection: Codable, Equatable {
    var url: URL
    var bookmarkData: Data?
    var isGenerated: Bool
}

struct StoredDisplayWallpaperAssignments: Codable, Equatable {
    var defaultSelection: StoredWallpaperSelection
    var perDisplaySelections: [String: StoredWallpaperSelection]

    var videoAssignment: DisplayVideoAssignment {
        DisplayVideoAssignment(
            defaultVideoURL: defaultSelection.url,
            videoURLByDisplayID: perDisplaySelections.mapValues { $0.url }
        )
    }

    func allSelections() -> [StoredWallpaperSelection] {
        [defaultSelection] + Array(perDisplaySelections.values)
    }
}

struct DisplayWallpaperAssignmentStore {
    static let userDefaultsKey = "DisplayWallpaperAssignments"

    var defaults: UserDefaults = .standard

    func load() -> StoredDisplayWallpaperAssignments? {
        do {
            return try loadChecked()
        } catch {
            Logger().error("Unable to read saved display assignments: \(error.localizedDescription)")
            return nil
        }
    }

    func loadChecked() throws -> StoredDisplayWallpaperAssignments? {
        guard let data = defaults.data(forKey: Self.userDefaultsKey) else {
            return nil
        }
        return try JSONDecoder().decode(StoredDisplayWallpaperAssignments.self, from: data)
    }

    func loadOrMigrate(
        legacySelection: () throws -> StoredWallpaperSelection?
    ) throws -> StoredDisplayWallpaperAssignments? {
        if let assignments = try loadChecked() {
            return assignments
        }
        guard let selection = try legacySelection() else { return nil }
        let assignments = StoredDisplayWallpaperAssignments(defaultSelection: selection, perDisplaySelections: [:])
        try save(assignments)
        return assignments
    }

    func save(_ assignments: StoredDisplayWallpaperAssignments) throws {
        let data = try JSONEncoder().encode(assignments)
        defaults.set(data, forKey: Self.userDefaultsKey)
    }

    func remove() {
        defaults.removeObject(forKey: Self.userDefaultsKey)
    }
}

struct DisplayWallpaperRestoration {
    var storedAssignments: StoredDisplayWallpaperAssignments
    var playbackAssignment: DisplayVideoAssignment?
    var unavailableURLs: Set<URL>

    static func restore(
        _ assignments: StoredDisplayWallpaperAssignments,
        connectedDisplayIDs: Set<String>,
        resolve: (StoredWallpaperSelection) -> StoredWallpaperSelection?,
        isAccessible: (URL) -> Bool
    ) -> Self {
        var stored = assignments
        var unavailable: Set<URL> = []
        var accessible: [String: URL] = [:]
        let defaultSelection = resolve(assignments.defaultSelection)
        if let defaultSelection {
            stored.defaultSelection = defaultSelection
        }
        let defaultURL: URL?
        if let defaultSelection, isAccessible(defaultSelection.url) {
            defaultURL = defaultSelection.url
        } else {
            defaultURL = nil
            unavailable.insert(assignments.defaultSelection.url)
        }
        for displayID in connectedDisplayIDs.sorted() {
            guard let selection = assignments.perDisplaySelections[displayID] else { continue }
            if let resolved = resolve(selection), isAccessible(resolved.url) {
                stored.perDisplaySelections[displayID] = resolved
                accessible[displayID] = resolved.url
            } else {
                unavailable.insert(selection.url)
            }
        }
        let fallback = defaultURL ?? accessible.sorted { $0.key < $1.key }.first?.value
        let playback = fallback.map {
            DisplayVideoAssignment(defaultVideoURL: $0, videoURLByDisplayID: accessible)
        }
        return Self(storedAssignments: stored, playbackAssignment: playback, unavailableURLs: unavailable)
    }
}
