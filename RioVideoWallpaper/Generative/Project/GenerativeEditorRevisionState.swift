//
//  GenerativeEditorRevisionState.swift
//  RioVideoWallpaper
//

import Foundation
import Combine

final class GenerativeEditorDraft: ObservableObject {
    var project: WallpaperProject?
    var revisionState = GenerativeEditorRevisionState()
    var library: GeneratedAssetLibrary?
    var projectURL: URL?
    var errorMessage: String?
}

struct GenerativeProjectSnapshot {
    var project: WallpaperProject
    var revision: UUID
    var library: GeneratedAssetLibrary
    var regenerateThumbnail: Bool
}

struct GenerativeEditorRevisionState {
    private(set) var revision = UUID()
    private(set) var pendingSave: GenerativeProjectSnapshot?

    mutating func recordEdit(
        _ project: WallpaperProject,
        library: GeneratedAssetLibrary,
        regenerateThumbnail: Bool
    ) throws {
        let pinnedLibrary = try library.pinned()
        revision = UUID()
        pendingSave = GenerativeProjectSnapshot(
            project: project,
            revision: revision,
            library: pinnedLibrary,
            regenerateThumbnail: regenerateThumbnail || pendingSave?.regenerateThumbnail == true
        )
    }

    func snapshot(_ project: WallpaperProject, library: GeneratedAssetLibrary) throws -> GenerativeProjectSnapshot {
        GenerativeProjectSnapshot(
            project: project,
            revision: revision,
            library: try library.pinned(),
            regenerateThumbnail: pendingSave?.regenerateThumbnail ?? false
        )
    }

    func matches(_ snapshot: GenerativeProjectSnapshot, project: WallpaperProject, library: GeneratedAssetLibrary) -> Bool {
        revision == snapshot.revision && project.id == snapshot.project.id &&
            library.rootURL.standardizedFileURL == snapshot.library.rootURL.standardizedFileURL
    }

    mutating func didSave(_ snapshot: GenerativeProjectSnapshot) {
        if pendingSave?.revision == snapshot.revision {
            pendingSave = nil
        }
    }

    mutating func beginProject() {
        precondition(pendingSave == nil, "Flush pending edits before replacing a project.")
        revision = UUID()
    }
}

enum GenerativeSnapshotPersistence {
    static func saveRecord(_ snapshot: GenerativeProjectSnapshot) throws -> SavedGeneratedProject {
        var project = snapshot.project
        if snapshot.regenerateThumbnail {
            project.assets.thumbnailPath = nil
        }
        let url = try snapshot.library.save(project)
        return SavedGeneratedProject(project: project, projectURL: url)
    }

    static func renderThumbnailData(
        for project: WallpaperProject,
        render: @escaping @Sendable (WallpaperProject) throws -> Data
    ) async throws -> Data {
        let worker = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            let data = try render(project)
            try Task.checkCancellation()
            return data
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func thumbnailErrorMessage(_ error: Error) -> String {
        String(
            format: AppLocalization.string("The project was saved, but its thumbnail could not be generated: %@"),
            error.localizedDescription
        )
    }
}
