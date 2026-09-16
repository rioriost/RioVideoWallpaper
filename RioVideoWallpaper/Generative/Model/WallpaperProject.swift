//
//  WallpaperProject.swift
//  RioVideoWallpaper
//

import Foundation

struct WallpaperProject: Codable, Equatable, Identifiable {
    var id: UUID
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var appVersion: String
    var rendererFamily: RendererFamily
    var rendererVersion: Int
    var promptHistory: [PromptEntry]
    var visualIntent: VisualIntent?
    var renderParameters: RenderParameters
    var seed: UInt64
    var exportSettings: ExportSettings
    var assets: ProjectAssets

    static func newFieldLinesProject(appVersion: String = "1.0") -> WallpaperProject {
        newProject(rendererFamily: .fieldLines, appVersion: appVersion)
    }

    static func newProject(rendererFamily: RendererFamily, appVersion: String = "1.0") -> WallpaperProject {
        let now = Date()
        return WallpaperProject(
            id: UUID(),
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now,
            appVersion: appVersion,
            rendererFamily: rendererFamily,
            rendererVersion: 1,
            promptHistory: [],
            visualIntent: nil,
            renderParameters: .defaultParameters(for: rendererFamily),
            seed: UInt64.random(in: UInt64.min...UInt64.max),
            exportSettings: .standard,
            assets: ProjectAssets(thumbnailPath: nil, outputVideoPath: nil)
        )
    }
}

struct PromptEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var prompt: String
    var responseSummary: String?
}

struct ProjectAssets: Codable, Equatable {
    var thumbnailPath: String?
    var outputVideoPath: String?
    var libraryRootPath: String? = nil
}
