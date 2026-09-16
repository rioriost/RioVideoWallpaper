//
//  GenerativeModelTests.swift
//  RioVideoWallpaperTests
//

import Foundation
import Metal
import Testing
@testable import RioVideoWallpaper

@Suite(.serialized)
struct GenerativeModelTests {
    @Test func renderClockUsesFixedLoopFrameCount() {
        let clock = RenderClock(fps: 30, loopSeconds: 10.0)

        #expect(clock.totalFrames == 300)
        #expect(clock.exportFrameIndices().count == 300)
        #expect(clock.normalizedLoopTime(frameIndex: 0) == 0.0)
        #expect(clock.normalizedLoopTime(frameIndex: 300) == 0.0)
        #expect(clock.warmupFrameIndices(warmupLoops: 1) == -300..<0)
    }

    @Test func seededRandomIsDeterministic() {
        var first = SeededRandom(seed: 42)
        var second = SeededRandom(seed: 42)

        #expect(first.next() == second.next())
        #expect(first.nextUnitDouble() == second.nextUnitDouble())
    }

    @Test func playbackSuspensionPolicySuspendsWhenScreensSleep() {
        let shouldSuspend = PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: true,
            frontmostPID: nil,
            currentPID: 1,
            windows: [],
            screens: []
        )

        #expect(shouldSuspend)
    }

    @Test func playbackSuspensionPolicySuspendsWhenFrontmostWindowCoversScreen() {
        let shouldSuspend = PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: false,
            frontmostPID: 10,
            currentPID: 1,
            windows: [
                PlaybackSuspensionPolicy.WindowSnapshot(
                    ownerPID: 10,
                    layer: 0,
                    width: 1439,
                    height: 899
                )
            ],
            screens: [
                PlaybackSuspensionPolicy.ScreenSnapshot(width: 1440, height: 900)
            ]
        )

        #expect(shouldSuspend)
    }

    @Test func playbackSuspensionPolicyIgnoresCurrentAppAndNonNormalLayers() {
        let screens = [PlaybackSuspensionPolicy.ScreenSnapshot(width: 1440, height: 900)]

        #expect(!PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: false,
            frontmostPID: 1,
            currentPID: 1,
            windows: [
                PlaybackSuspensionPolicy.WindowSnapshot(ownerPID: 1, layer: 0, width: 1440, height: 900)
            ],
            screens: screens
        ))

        #expect(!PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: false,
            frontmostPID: 10,
            currentPID: 1,
            windows: [
                PlaybackSuspensionPolicy.WindowSnapshot(ownerPID: 10, layer: 25, width: 1440, height: 900)
            ],
            screens: screens
        ))
    }

    @Test func playbackSuspensionPolicyKeepsPlayingForSmallerFrontmostWindow() {
        let shouldSuspend = PlaybackSuspensionPolicy.shouldSuspend(
            screensAreSleeping: false,
            frontmostPID: 10,
            currentPID: 1,
            windows: [
                PlaybackSuspensionPolicy.WindowSnapshot(
                    ownerPID: 10,
                    layer: 0,
                    width: 1200,
                    height: 800
                )
            ],
            screens: [
                PlaybackSuspensionPolicy.ScreenSnapshot(width: 1440, height: 900)
            ]
        )

        #expect(!shouldSuspend)
    }

    @Test func displayWallpaperAssignmentsExposeDefaultAndPerDisplayURLs() {
        let defaultURL = URL(fileURLWithPath: "/tmp/default.mp4")
        let sideURL = URL(fileURLWithPath: "/tmp/side.mp4")
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: StoredWallpaperSelection(url: defaultURL, bookmarkData: nil, isGenerated: true),
            perDisplaySelections: [
                "display-2": StoredWallpaperSelection(url: sideURL, bookmarkData: Data([1, 2, 3]), isGenerated: false)
            ]
        )

        #expect(assignments.videoAssignment.defaultVideoURL == defaultURL)
        #expect(assignments.videoAssignment.videoURLByDisplayID["display-2"] == sideURL)
        #expect(assignments.allSelections().count == 2)
    }

    @Test func displayWallpaperAssignmentStoreRoundTripsThroughUserDefaults() throws {
        let suiteName = "RioVideoWallpaperTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = DisplayWallpaperAssignmentStore(defaults: defaults)
        let assignments = StoredDisplayWallpaperAssignments(
            defaultSelection: StoredWallpaperSelection(
                url: URL(fileURLWithPath: "/tmp/default.mp4"),
                bookmarkData: Data([1, 2, 3]),
                isGenerated: false
            ),
            perDisplaySelections: [
                "display-2": StoredWallpaperSelection(
                    url: URL(fileURLWithPath: "/tmp/generated.mp4"),
                    bookmarkData: nil,
                    isGenerated: true
                )
            ]
        )

        try store.save(assignments)

        #expect(store.load() == assignments)
        store.remove()
        #expect(store.load() == nil)
    }

    @Test func fieldLinesProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.rendererFamily == .fieldLines)
        #expect(decoded.rendererVersion == 1)
        #expect(decoded.exportSettings == .standard)
        #expect(decoded.renderParameters.rendererFamily == .fieldLines)
    }

    @Test func orbitalProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .orbital, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .orbital)
        #expect(decoded.renderParameters.rendererFamily == .orbital)
        guard case .orbital(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Orbital render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func softVolumetricProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .softVolumetric, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .softVolumetric)
        #expect(decoded.renderParameters.rendererFamily == .softVolumetric)
        guard case .softVolumetric(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Soft Volumetric render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func gridCityProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .gridCity, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .gridCity)
        #expect(decoded.renderParameters.rendererFamily == .gridCity)
        guard case .gridCity(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Grid City render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func interferenceFieldProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .interferenceField, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .interferenceField)
        #expect(decoded.renderParameters.rendererFamily == .interferenceField)
        guard case .interferenceField(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Interference Field render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func periodicNoiseProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .periodicNoise, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .periodicNoise)
        #expect(decoded.renderParameters.rendererFamily == .periodicNoise)
        guard case .periodicNoise(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Periodic Noise render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func cyclicAutomataProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .cyclicAutomata, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .cyclicAutomata)
        #expect(decoded.renderParameters.rendererFamily == .cyclicAutomata)
        guard case .cyclicAutomata(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Cyclic Automata render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func agentSwarmProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .agentSwarm, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .agentSwarm)
        #expect(decoded.renderParameters.rendererFamily == .agentSwarm)
        guard case .agentSwarm(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Agent Swarm render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func kaleidoscopeProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .kaleidoscope, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .kaleidoscope)
        #expect(decoded.renderParameters.rendererFamily == .kaleidoscope)
        guard case .kaleidoscope(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Kaleidoscope render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func voronoiFlowProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .voronoiFlow, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .voronoiFlow)
        #expect(decoded.renderParameters.rendererFamily == .voronoiFlow)
        guard case .voronoiFlow(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Voronoi Flow render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func reactionDiffusionProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .reactionDiffusion, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .reactionDiffusion)
        #expect(decoded.renderParameters.rendererFamily == .reactionDiffusion)
        guard case .reactionDiffusion(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Reaction Diffusion render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func plasmaFieldProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .plasmaField, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .plasmaField)
        #expect(decoded.renderParameters.rendererFamily == .plasmaField)
        guard case .plasmaField(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Plasma Field render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func harmonicTunnelProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .harmonicTunnel, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .harmonicTunnel)
        #expect(decoded.renderParameters.rendererFamily == .harmonicTunnel)
        guard case .harmonicTunnel(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Harmonic Tunnel render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func lissajousWeaveProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .lissajousWeave, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .lissajousWeave)
        #expect(decoded.renderParameters.rendererFamily == .lissajousWeave)
        guard case .lissajousWeave(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Lissajous Weave render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func phyllotaxisBloomProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .phyllotaxisBloom, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .phyllotaxisBloom)
        #expect(decoded.renderParameters.rendererFamily == .phyllotaxisBloom)
        guard case .phyllotaxisBloom(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Phyllotaxis Bloom render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func hexPulseLatticeProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .hexPulseLattice, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .hexPulseLattice)
        #expect(decoded.renderParameters.rendererFamily == .hexPulseLattice)
        guard case .hexPulseLattice(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Hex Pulse Lattice render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func superformulaMorphProjectRoundTripsThroughJSON() throws {
        let project = WallpaperProject.newProject(rendererFamily: .superformulaMorph, appVersion: "test")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WallpaperProject.self, from: data)

        #expect(decoded.rendererFamily == .superformulaMorph)
        #expect(decoded.renderParameters.rendererFamily == .superformulaMorph)
        guard case .superformulaMorph(let parameters) = decoded.renderParameters else {
            Issue.record("Expected Superformula Morph render parameters")
            return
        }
        #expect(parameters == .defaultParameters)
    }

    @Test func allRendererFamilyProjectsRoundTripThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        #expect(RendererFamily.allCases.count == 67)

        for rendererFamily in RendererFamily.allCases {
            let project = WallpaperProject.newProject(rendererFamily: rendererFamily, appVersion: "test")
            let data = try encoder.encode(project)
            let decoded = try decoder.decode(WallpaperProject.self, from: data)

            #expect(decoded.rendererFamily == rendererFamily)
            #expect(decoded.renderParameters.rendererFamily == rendererFamily)
        }
    }

    @Test func projectFileStoreSavesAndLoadsProject() throws {
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.createdAt = Date(timeIntervalSince1970: 10)
        project.updatedAt = Date(timeIntervalSince1970: 20)
        project.seed = 123
        project.promptHistory = [
            PromptEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
                createdAt: Date(timeIntervalSince1970: 30),
                prompt: "calm blue lines",
                responseSummary: "Calm blue field lines"
            )
        ]

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperProject-\(UUID().uuidString)")
        let expectedURL = outputURL.appendingPathExtension(WallpaperProjectFileStore.fileExtension)
        defer {
            try? FileManager.default.removeItem(at: expectedURL)
        }

        try WallpaperProjectFileStore.save(project, to: outputURL)
        let loadedProject = try WallpaperProjectFileStore.load(from: expectedURL)

        #expect(FileManager.default.fileExists(atPath: expectedURL.path))
        #expect(loadedProject == project)
    }

    @Test func projectFileStoreRejectsInvalidData() {
        #expect(throws: Error.self) {
            _ = try WallpaperProjectFileStore.decode(Data("not json".utf8))
        }
    }

    @Test func projectSanitizerClampsLoadedProjectsAndInvalidatesGeneratedVideo() {
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.assets.outputVideoPath = "/tmp/stale-generated.mp4"
        project.assets.thumbnailPath = "/tmp/stale-thumbnail.png"
        project.exportSettings = ExportSettings(
            width: 0,
            height: 0,
            fps: 0,
            loopSeconds: 0,
            codec: .h264,
            quality: .draft,
            warmupLoops: -1
        )
        project.renderParameters = .fieldLines(FieldLinesParameters(
            bandCount: 999,
            pointsPerBand: 999_999,
            particleCount: 999_999,
            fadeAlpha: -1,
            lineStep: 999,
            hueBaseDegrees: -10,
            hueDriftDegrees: 999,
            saturation: 999,
            brightness: 999,
            lineAlpha: 999,
            particleAlpha: 999,
            lineWeight: 999,
            speed: 999,
            turbulence: 999
        ))

        let result = WallpaperProjectSanitizer.sanitize(project, reducedMotion: true)
        let sanitizedProject = result.project

        guard case .fieldLines(let parameters) = sanitizedProject.renderParameters else {
            Issue.record("Expected FieldLines render parameters")
            return
        }

        #expect(result.madeChanges)
        #expect(result.adjustedRenderParameters)
        #expect(result.adjustedExportSettings)
        #expect(!result.adjustedVisualIntent)
        #expect(!result.removedVisualIntent)
        #expect(result.invalidatedOutputVideo)
        #expect(parameters.bandCount == RendererCapabilities.fieldLines.fieldLinesLimits.bandCount.upperBound)
        #expect(parameters.hueBaseDegrees == 350)
        #expect(parameters.lineStep == RendererCapabilities.fieldLines.fieldLinesLimits.lineStep.upperBound)
        #expect(parameters.brightness == PhotosensitivitySafetyPolicy.maxBrightness)
        #expect(parameters.speed == PhotosensitivitySafetyPolicy.reducedMotionMaxSpeed)
        #expect(parameters.turbulence == PhotosensitivitySafetyPolicy.reducedMotionMaxTurbulence)
        #expect(sanitizedProject.exportSettings.width == ExportSettings.minimumWidth)
        #expect(sanitizedProject.exportSettings.height == ExportSettings.minimumHeight)
        #expect(sanitizedProject.exportSettings.fps == ExportSettings.minimumFPS)
        #expect(sanitizedProject.exportSettings.loopSeconds == ExportSettings.minimumLoopSeconds)
        #expect(sanitizedProject.assets.outputVideoPath == nil)
        #expect(sanitizedProject.assets.thumbnailPath == project.assets.thumbnailPath)
    }

    @Test func exportPresetsUseExpectedDisplaySizes() throws {
        let presets = ExportPreset.allCases.filter { $0 != .custom }
        let sizes = try presets.map { preset -> String in
            let settings = try #require(preset.baseSettings)
            return "\(settings.width)x\(settings.height)"
        }

        #expect(sizes == [
            "1280x800",
            "1440x900",
            "1920x1080",
            "1920x1200",
            "2560x1080",
            "2560x1440",
            "2560x1600",
            "2880x1800",
            "3440x1440",
            "3840x2160",
            "3840x2560",
            "4096x2160",
            "5120x1440",
            "5120x2160",
            "5120x2880",
            "6016x3384",
            "7680x4320"
        ])
        #expect(presets.map(\.displayName) == [
            "1280x800",
            "1440x900",
            "1920x1080 (Full HD)",
            "1920x1200 (WUXGA)",
            "2560x1080 (WFHD)",
            "2560x1440 (WQHD)",
            "2560x1600 (WQXGA)",
            "2880x1800",
            "3440x1440 (UWQHD)",
            "3840x2160 (4K)",
            "3840x2560 (4K+)",
            "4096x2160 (DCI 4K)",
            "5120x1440 (DQHD)",
            "5120x2160 (WUHD)",
            "5120x2880 (5K)",
            "6016x3384 (6K)",
            "7680x4320 (8K)"
        ])

        for preset in presets {
            let settings = try #require(preset.baseSettings)
            #expect(settings.fps == 30)
            #expect(settings.loopSeconds == 10)
            #expect(settings.quality == .high)
            #expect(settings.warmupLoops == 1)
        }
    }

    @Test func exportPresetMatchingIgnoresCodecAndDetectsCustomSettings() throws {
        var settings = try #require(ExportPreset.size2560x1600.exportSettings(preservingCodec: .hevc))

        #expect(settings.codec == .hevc)
        #expect(ExportPreset.matching(settings) == .size2560x1600)

        settings.loopSeconds = 12

        #expect(ExportPreset.matching(settings) == .custom)
    }

    @Test func exportSettingsNormalizeUnsafeValuesForExporter() {
        let settings = ExportSettings(
            width: 0,
            height: -10,
            fps: 0,
            loopSeconds: 0,
            codec: .h264,
            quality: .draft,
            warmupLoops: -2
        ).normalizedForExport()

        #expect(settings.width == ExportSettings.minimumWidth)
        #expect(settings.height == ExportSettings.minimumHeight)
        #expect(settings.fps == ExportSettings.minimumFPS)
        #expect(settings.loopSeconds == ExportSettings.minimumLoopSeconds)
        #expect(settings.warmupLoops == ExportSettings.minimumWarmupLoops)
    }

    @Test func generatedAssetLibrarySavesAndListsProjectsNewestFirst() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibrary-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var olderProject = WallpaperProject.newFieldLinesProject(appVersion: "test")
        olderProject.id = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        olderProject.updatedAt = Date(timeIntervalSince1970: 100)
        olderProject.visualIntent = PromptInterpreter.interpret("calm blue lines", seed: olderProject.seed)
        olderProject.promptHistory = [
            PromptEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                createdAt: Date(timeIntervalSince1970: 90),
                prompt: "calm blue lines",
                responseSummary: "Calm blue lines"
            )
        ]

        var newerProject = WallpaperProject.newFieldLinesProject(appVersion: "test")
        newerProject.id = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        newerProject.updatedAt = Date(timeIntervalSince1970: 200)
        newerProject.assets.outputVideoPath = "/tmp/generated.mp4"
        newerProject.visualIntent = PromptInterpreter.interpret("fast neon particles", seed: newerProject.seed)

        let olderURL = try library.save(olderProject)
        let newerURL = try library.save(newerProject)
        let entries = try library.listProjects()

        #expect(FileManager.default.fileExists(atPath: olderURL.path))
        #expect(FileManager.default.fileExists(atPath: newerURL.path))
        #expect(entries.map(\.projectID) == [newerProject.id, olderProject.id])
        #expect(entries.first?.outputVideoPath == "/tmp/generated.mp4")
        #expect(entries.last?.promptPreview == "calm blue lines")
    }

    @Test func generatedAssetLibraryLoadsEntryProject() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryLoad-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.id = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        project.createdAt = Date(timeIntervalSince1970: 290)
        project.updatedAt = Date(timeIntervalSince1970: 300)

        _ = try library.save(project)
        let entry = try #require(library.listProjects().first)
        let loadedProject = try library.load(entry)

        #expect(loadedProject == project)
    }

    @Test func generatedAssetLibraryDeletesProjectAndOwnedAssetsOnly() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryDelete-\(UUID().uuidString)", isDirectory: true)
        let externalVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryExternal-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: externalVideoURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var projectWithOwnedAssets = WallpaperProject.newFieldLinesProject(appVersion: "test")
        projectWithOwnedAssets.id = UUID(uuidString: "00000000-0000-0000-0000-000000000451")!
        let ownedVideoURL = try library.videoURL(for: projectWithOwnedAssets)
        let ownedThumbnailURL = try library.thumbnailURL(for: projectWithOwnedAssets)
        try Data("video".utf8).write(to: ownedVideoURL)
        try Data("thumbnail".utf8).write(to: ownedThumbnailURL)
        projectWithOwnedAssets.assets.outputVideoPath = ownedVideoURL.path
        projectWithOwnedAssets.assets.thumbnailPath = ownedThumbnailURL.path

        var projectWithExternalVideo = WallpaperProject.newFieldLinesProject(appVersion: "test")
        projectWithExternalVideo.id = UUID(uuidString: "00000000-0000-0000-0000-000000000452")!
        try Data("external".utf8).write(to: externalVideoURL)
        projectWithExternalVideo.assets.outputVideoPath = externalVideoURL.path

        let ownedProjectURL = try library.save(projectWithOwnedAssets)
        let externalProjectURL = try library.save(projectWithExternalVideo)
        let entries = try library.listProjects()
        let ownedEntry = try #require(entries.first { $0.projectID == projectWithOwnedAssets.id })
        let externalEntry = try #require(entries.first { $0.projectID == projectWithExternalVideo.id })

        try library.delete(ownedEntry)
        try library.delete(externalEntry)

        #expect(!FileManager.default.fileExists(atPath: ownedProjectURL.path))
        #expect(!FileManager.default.fileExists(atPath: ownedVideoURL.path))
        #expect(!FileManager.default.fileExists(atPath: ownedThumbnailURL.path))
        #expect(!FileManager.default.fileExists(atPath: externalProjectURL.path))
        #expect(FileManager.default.fileExists(atPath: externalVideoURL.path))
        #expect(try library.listProjects().isEmpty)
    }

    @Test func generatedAssetLibraryProvidesRevisionVideoOutputURLs() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryVideo-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.id = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!

        let videoURL = try library.videoURL(for: project)
        let movURL = try library.videoURL(for: project, fileExtension: ".mov")

        #expect(videoURL.deletingLastPathComponent() == library.videosDirectoryURL)
        #expect(videoURL.lastPathComponent.hasPrefix(project.id.uuidString + "-"))
        #expect(videoURL != (try library.videoURL(for: project)))
        #expect(movURL.pathExtension == "mov")
        #expect(FileManager.default.fileExists(atPath: library.videosDirectoryURL.path))
    }

    @Test func generatedAssetLibraryDetectsOwnedGeneratedVideos() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryOwnedVideo-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        let project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        let videoURL = try library.videoURL(for: project)
        let thumbnailURL = try library.thumbnailURL(for: project)
        let externalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryExternal-\(UUID().uuidString).mp4")

        #expect(library.containsGeneratedVideo(videoURL))
        #expect(!library.containsGeneratedVideo(thumbnailURL))
        #expect(!library.containsGeneratedVideo(externalURL))
    }

    @Test func generatedAssetLibraryCleansOnlyOrphanedOwnedAssets() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryCleanup-\(UUID().uuidString)", isDirectory: true)
        let externalVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryCleanupExternal-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: externalVideoURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.id = UUID(uuidString: "00000000-0000-0000-0000-000000000551")!
        let referencedVideoURL = try library.videoURL(for: project)
        let referencedThumbnailURL = try library.thumbnailURL(for: project)
        let orphanVideoURL = library.videosDirectoryURL.appendingPathComponent("orphan").appendingPathExtension("mp4")
        let orphanThumbnailURL = library.thumbnailsDirectoryURL.appendingPathComponent("orphan").appendingPathExtension("png")
        try Data("video".utf8).write(to: referencedVideoURL)
        try Data("thumbnail".utf8).write(to: referencedThumbnailURL)
        try Data("orphan-video".utf8).write(to: orphanVideoURL)
        try Data("orphan-thumbnail".utf8).write(to: orphanThumbnailURL)
        try Data("external".utf8).write(to: externalVideoURL)
        project.assets.outputVideoPath = referencedVideoURL.path
        project.assets.thumbnailPath = referencedThumbnailURL.path

        _ = try library.save(project)
        let report = try library.cleanupOrphanedAssets()

        #expect(report.removedVideoCount == 1)
        #expect(report.removedThumbnailCount == 1)
        #expect(FileManager.default.fileExists(atPath: referencedVideoURL.path))
        #expect(FileManager.default.fileExists(atPath: referencedThumbnailURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanVideoURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanThumbnailURL.path))
        #expect(FileManager.default.fileExists(atPath: externalVideoURL.path))
    }

    @Test func generatedAssetLibraryProvidesStableThumbnailURL() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeneratedAssetLibraryThumbnail-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let library = GeneratedAssetLibrary(rootURL: rootURL)
        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.id = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!

        let thumbnailURL = try library.thumbnailURL(for: project)
        let rawURL = try library.thumbnailURL(for: project, fileExtension: "")

        #expect(thumbnailURL == library.thumbnailsDirectoryURL.appendingPathComponent(project.id.uuidString).appendingPathExtension("png"))
        #expect(rawURL.pathExtension.isEmpty)
        #expect(FileManager.default.fileExists(atPath: library.thumbnailsDirectoryURL.path))
    }

    @Test func thumbnailRendererCreatesPNGData() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let pngData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let pngSignature = Array(pngData.prefix(8))

        #expect(pngSignature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(pngData.count > 100)
    }

    @Test func thumbnailRendererCreatesOrbitalPNGData() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .orbital, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let pngData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let pngSignature = Array(pngData.prefix(8))

        #expect(pngSignature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(pngData.count > 100)
    }

    @Test func thumbnailRendererCreatesSoftVolumetricPNGData() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .softVolumetric, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let pngData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let pngSignature = Array(pngData.prefix(8))

        #expect(pngSignature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(pngData.count > 100)
    }

    @Test func thumbnailRendererCreatesGridCityPNGData() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .gridCity, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let pngData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let pngSignature = Array(pngData.prefix(8))

        #expect(pngSignature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(pngData.count > 100)
    }

    @Test func thumbnailRendererCreatesClosedFlowPNGData() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .closedFlowParticles, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let pngData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let pngSignature = Array(pngData.prefix(8))

        #expect(pngSignature == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(pngData.count > 100)
    }

    @Test func thumbnailRendererIsDeterministicForSameProject() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.seed = 42
        project.renderParameters = .fieldLines(.feasibilityStudyDefault)
        project.exportSettings = ExportSettings(
            width: 64,
            height: 40,
            fps: 2,
            loopSeconds: 4,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        var differentSeedProject = project
        differentSeedProject.seed = 43

        let firstPNGData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let secondPNGData = try GenerativeThumbnailRenderer.renderPNG(project: project, size: CGSize(width: 64, height: 40))
        let differentSeedPNGData = try GenerativeThumbnailRenderer.renderPNG(project: differentSeedProject, size: CGSize(width: 64, height: 40))

        #expect(firstPNGData == secondPNGData)
        #expect(firstPNGData != differentSeedPNGData)
    }

    @Test func promptInterpreterMapsKeywordsToFieldLinesParameters() {
        let intent = PromptInterpreter.interpret("calm blue cosmic long trail", seed: 42)
        let parameters = PromptInterpreter.makeFieldLinesParameters(from: intent)
        let renderParameters = IntentToRenderParametersMapper.renderParameters(from: intent)
        let exportSettings = PromptInterpreter.exportSettings(.standard, applying: intent)

        #expect(intent.rendererFamily == .fieldLines)
        #expect(intent.palette.hueBaseDegrees == 215)
        #expect(intent.motion.speed < 1.0)
        #expect(intent.motion.trailLength > 0.8)
        #expect(parameters.hueBaseDegrees == 215)
        #expect(renderParameters.rendererFamily == .fieldLines)
        #expect(parameters.fadeAlpha < FieldLinesParameters.feasibilityStudyDefault.fadeAlpha)
        #expect(exportSettings.loopSeconds > ExportSettings.standard.loopSeconds)
    }

    @Test func intentMapperUsesLineStepForSemanticStructure() {
        let smoothIntent = PromptInterpreter.interpret("smooth minimal quiet ribbon", seed: 5)
        let chaoticIntent = PromptInterpreter.interpret("dense chaotic storm grid lines", seed: 5)
        let smoothParameters = PromptInterpreter.makeFieldLinesParameters(from: smoothIntent)
        let chaoticParameters = PromptInterpreter.makeFieldLinesParameters(from: chaoticIntent)

        #expect(chaoticParameters.lineStep > smoothParameters.lineStep)
        #expect(RendererCapabilities.fieldLines.fieldLinesLimits.lineStep.contains(smoothParameters.lineStep))
        #expect(RendererCapabilities.fieldLines.fieldLinesLimits.lineStep.contains(chaoticParameters.lineStep))
    }

    @Test func intentMapperClampsParametersToRendererCapabilities() {
        var intent = PromptInterpreter.interpret("dense neon particle storm", seed: 1)
        intent.palette.hueBaseDegrees = -30
        intent.palette.hueSpreadDegrees = 720
        intent.palette.saturation = 2.0
        intent.palette.brightness = 3.0
        intent.composition.density = 10
        intent.motion.loopSeconds = 100
        intent.motion.speed = 20
        intent.motion.turbulence = 20
        intent.motion.trailLength = 20
        intent.elements.particleAmount = 10
        intent.elements.lineAmount = 10
        intent.elements.glowAmount = 10

        let capabilities = RendererCapabilities.fieldLines
        let parameters = IntentToRenderParametersMapper.fieldLinesParameters(from: intent, capabilities: capabilities)
        let exportSettings = IntentToRenderParametersMapper.exportSettings(
            ExportSettings.standard,
            applying: intent
        )

        #expect(capabilities.supportedIntentSchemaVersions.contains(intent.schemaVersion))
        #expect(parameters.hueBaseDegrees == 330)
        #expect(parameters.hueDriftDegrees == capabilities.fieldLinesLimits.hueDriftDegrees.upperBound)
        #expect(parameters.saturation == capabilities.fieldLinesLimits.saturation.upperBound)
        #expect(parameters.brightness == PhotosensitivitySafetyPolicy.maxBrightness)
        #expect(parameters.particleCount == capabilities.fieldLinesLimits.particleCount.upperBound)
        #expect(parameters.speed == PhotosensitivitySafetyPolicy.maxSpeedWhenPulsing)
        #expect(parameters.turbulence == PhotosensitivitySafetyPolicy.maxTurbulenceWhenPulsing)
        #expect(exportSettings.loopSeconds == 30)
    }

    @Test func intentMapperCreatesOrbitalParametersForOrbitalIntent() {
        var intent = PromptInterpreter.interpret("dense cosmic orbit particles", seed: 11)
        intent.rendererFamily = .orbital
        intent.palette.hueBaseDegrees = -45
        intent.motion.speed = 20
        intent.elements.objectAmount = 1

        let capabilities = RendererCapabilities.orbital
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .orbital(let parameters) = renderParameters else {
            Issue.record("Expected Orbital render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 315)
        #expect(parameters.orbitCount <= capabilities.orbitalLimits.orbitCount.upperBound)
        #expect(parameters.satelliteCount <= capabilities.orbitalLimits.satelliteCount.upperBound)
        #expect(parameters.speed == capabilities.orbitalLimits.speed.upperBound)
    }

    @Test func intentMapperCreatesSoftVolumetricParametersForSoftVolumetricIntent() {
        var intent = PromptInterpreter.interpret("soft glowing mist nebula", seed: 12)
        intent.rendererFamily = .softVolumetric
        intent.palette.hueBaseDegrees = -60
        intent.motion.turbulence = 20
        intent.elements.glowAmount = 1

        let capabilities = RendererCapabilities.softVolumetric
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .softVolumetric(let parameters) = renderParameters else {
            Issue.record("Expected Soft Volumetric render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 300)
        #expect(parameters.cloudCount <= capabilities.softVolumetricLimits.cloudCount.upperBound)
        #expect(parameters.pointsPerCloud <= capabilities.softVolumetricLimits.pointsPerCloud.upperBound)
        #expect(parameters.turbulence == capabilities.softVolumetricLimits.turbulence.upperBound)
    }

    @Test func intentMapperCreatesGridCityParametersForGridCityIntent() {
        var intent = PromptInterpreter.interpret("dense neon future city grid", seed: 13)
        intent.rendererFamily = .gridCity
        intent.palette.hueBaseDegrees = -90
        intent.motion.speed = 20
        intent.elements.gridAmount = 1

        let capabilities = RendererCapabilities.gridCity
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .gridCity(let parameters) = renderParameters else {
            Issue.record("Expected Grid City render parameters")
            return
        }

        #expect(capabilities.gridCityLimits.laneCount.contains(parameters.laneCount))
        #expect(capabilities.gridCityLimits.towerCount.contains(parameters.towerCount))
        #expect(capabilities.gridCityLimits.speed.contains(parameters.speed))
        #expect(capabilities.gridCityLimits.brightness.contains(parameters.brightness))
    }

    @Test func intentMapperCreatesInterferenceFieldParametersForInterferenceIntent() {
        var intent = PromptInterpreter.interpret("gold quasicrystal moire interference", seed: 14)
        intent.rendererFamily = .interferenceField
        intent.palette.hueBaseDegrees = -120
        intent.motion.speed = 20
        intent.composition.symmetry = 1
        intent.palette.contrast = 1

        let capabilities = RendererCapabilities.interferenceField
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .interferenceField(let parameters) = renderParameters else {
            Issue.record("Expected Interference Field render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 240)
        #expect(capabilities.interferenceFieldLimits.waveCount.contains(parameters.waveCount))
        #expect(capabilities.interferenceFieldLimits.samplesPerAxis.contains(parameters.samplesPerAxis))
        #expect(capabilities.interferenceFieldLimits.speed.contains(parameters.speed))
        #expect(parameters.contrast <= PhotosensitivitySafetyPolicy.maxContrast)
    }

    @Test func intentMapperCreatesPeriodicNoiseParametersForFluidIntent() {
        var intent = PromptInterpreter.interpret("flowing marble water caustics", seed: 15)
        intent.rendererFamily = .periodicNoise
        intent.palette.hueBaseDegrees = -40
        intent.motion.speed = 20
        intent.motion.turbulence = 2
        intent.palette.contrast = 1

        let capabilities = RendererCapabilities.periodicNoise
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .periodicNoise(let parameters) = renderParameters else {
            Issue.record("Expected Periodic Noise render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 320)
        #expect(capabilities.periodicNoiseLimits.samplesPerAxis.contains(parameters.samplesPerAxis))
        #expect(capabilities.periodicNoiseLimits.octaveCount.contains(parameters.octaveCount))
        #expect(capabilities.periodicNoiseLimits.speed.contains(parameters.speed))
        #expect(parameters.contourSharpness <= PhotosensitivitySafetyPolicy.maxContrast)
    }

    @Test func intentMapperCreatesCyclicAutomataParametersForCellularIntent() {
        var intent = PromptInterpreter.interpret("cellular automata reaction diffusion", seed: 16)
        intent.rendererFamily = .cyclicAutomata
        intent.palette.hueBaseDegrees = -20
        intent.motion.speed = 20
        intent.motion.turbulence = 2
        intent.palette.contrast = 1

        let capabilities = RendererCapabilities.cyclicAutomata
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .cyclicAutomata(let parameters) = renderParameters else {
            Issue.record("Expected Cyclic Automata render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 340)
        #expect(capabilities.cyclicAutomataLimits.cellsPerAxis.contains(parameters.cellsPerAxis))
        #expect(capabilities.cyclicAutomataLimits.stateCount.contains(parameters.stateCount))
        #expect(capabilities.cyclicAutomataLimits.speed.contains(parameters.speed))
        #expect(parameters.edgeSharpness <= PhotosensitivitySafetyPolicy.maxContrast)
    }

    @Test func intentMapperCreatesAgentSwarmParametersForSwarmIntent() {
        var intent = PromptInterpreter.interpret("firefly swarm migrating lights", seed: 17)
        intent.rendererFamily = .agentSwarm
        intent.palette.hueBaseDegrees = -60
        intent.motion.speed = 20
        intent.motion.turbulence = 2
        intent.composition.density = 1

        let capabilities = RendererCapabilities.agentSwarm
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .agentSwarm(let parameters) = renderParameters else {
            Issue.record("Expected Agent Swarm render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 300)
        #expect(capabilities.agentSwarmLimits.agentCount.contains(parameters.agentCount))
        #expect(capabilities.agentSwarmLimits.trailCount.contains(parameters.trailCount))
        #expect(capabilities.agentSwarmLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesKaleidoscopeParametersForSymmetryIntent() {
        var intent = PromptInterpreter.interpret("vivid kaleidoscope mandala stained glass", seed: 18)
        intent.rendererFamily = .kaleidoscope
        intent.palette.hueBaseDegrees = -90
        intent.motion.speed = 20
        intent.composition.symmetry = 1
        intent.composition.density = 1

        let capabilities = RendererCapabilities.kaleidoscope
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .kaleidoscope(let parameters) = renderParameters else {
            Issue.record("Expected Kaleidoscope render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 270)
        #expect(capabilities.kaleidoscopeLimits.ringCount.contains(parameters.ringCount))
        #expect(capabilities.kaleidoscopeLimits.segments.contains(parameters.segments))
        #expect(capabilities.kaleidoscopeLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesVoronoiFlowParametersForMosaicIntent() {
        var intent = PromptInterpreter.interpret("liquid voronoi mosaic bubbles", seed: 19)
        intent.rendererFamily = .voronoiFlow
        intent.palette.hueBaseDegrees = -120
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.voronoiFlow
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .voronoiFlow(let parameters) = renderParameters else {
            Issue.record("Expected Voronoi Flow render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 240)
        #expect(capabilities.voronoiFlowLimits.siteCount.contains(parameters.siteCount))
        #expect(capabilities.voronoiFlowLimits.samplesPerAxis.contains(parameters.samplesPerAxis))
        #expect(capabilities.voronoiFlowLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesReactionDiffusionParametersForTuringIntent() {
        var intent = PromptInterpreter.interpret("reaction diffusion turing pattern coral", seed: 20)
        intent.rendererFamily = .reactionDiffusion
        intent.palette.hueBaseDegrees = -150
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.reactionDiffusion
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .reactionDiffusion(let parameters) = renderParameters else {
            Issue.record("Expected Reaction Diffusion render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 210)
        #expect(capabilities.reactionDiffusionLimits.samplesPerAxis.contains(parameters.samplesPerAxis))
        #expect(capabilities.reactionDiffusionLimits.layerCount.contains(parameters.layerCount))
        #expect(capabilities.reactionDiffusionLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesPlasmaFieldParametersForPlasmaIntent() {
        var intent = PromptInterpreter.interpret("electric plasma lava lamp", seed: 21)
        intent.rendererFamily = .plasmaField
        intent.palette.hueBaseDegrees = -180
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.plasmaField
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .plasmaField(let parameters) = renderParameters else {
            Issue.record("Expected Plasma Field render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 180)
        #expect(capabilities.plasmaFieldLimits.samplesPerAxis.contains(parameters.samplesPerAxis))
        #expect(capabilities.plasmaFieldLimits.octaveCount.contains(parameters.octaveCount))
        #expect(capabilities.plasmaFieldLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesHarmonicTunnelParametersForTunnelIntent() {
        var intent = PromptInterpreter.interpret("hyperspace warp tunnel", seed: 22)
        intent.rendererFamily = .harmonicTunnel
        intent.palette.hueBaseDegrees = -90
        intent.motion.speed = 20
        intent.composition.depth = 1

        let capabilities = RendererCapabilities.harmonicTunnel
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .harmonicTunnel(let parameters) = renderParameters else {
            Issue.record("Expected Harmonic Tunnel render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 270)
        #expect(capabilities.harmonicTunnelLimits.ringCount.contains(parameters.ringCount))
        #expect(capabilities.harmonicTunnelLimits.pointsPerRing.contains(parameters.pointsPerRing))
        #expect(capabilities.harmonicTunnelLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesLissajousWeaveParametersForCurveIntent() {
        var intent = PromptInterpreter.interpret("laser lissajous oscilloscope", seed: 23)
        intent.rendererFamily = .lissajousWeave
        intent.palette.hueBaseDegrees = -45
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.lissajousWeave
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .lissajousWeave(let parameters) = renderParameters else {
            Issue.record("Expected Lissajous Weave render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 315)
        #expect(capabilities.lissajousWeaveLimits.curveCount.contains(parameters.curveCount))
        #expect(capabilities.lissajousWeaveLimits.pointsPerCurve.contains(parameters.pointsPerCurve))
        #expect(capabilities.lissajousWeaveLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesPhyllotaxisBloomParametersForBloomIntent() {
        var intent = PromptInterpreter.interpret("sunflower spiral phyllotaxis bloom", seed: 24)
        intent.rendererFamily = .phyllotaxisBloom
        intent.palette.hueBaseDegrees = -15
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.phyllotaxisBloom
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .phyllotaxisBloom(let parameters) = renderParameters else {
            Issue.record("Expected Phyllotaxis Bloom render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 345)
        #expect(capabilities.phyllotaxisBloomLimits.pointCount.contains(parameters.pointCount))
        #expect(capabilities.phyllotaxisBloomLimits.armCount.contains(parameters.armCount))
        #expect(capabilities.phyllotaxisBloomLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesHexPulseLatticeParametersForHexIntent() {
        var intent = PromptInterpreter.interpret("neon honeycomb hex grid circuit panel", seed: 24)
        intent.rendererFamily = .hexPulseLattice
        intent.palette.hueBaseDegrees = -15
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.hexPulseLattice
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .hexPulseLattice(let parameters) = renderParameters else {
            Issue.record("Expected Hex Pulse Lattice render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 345)
        #expect(capabilities.hexPulseLatticeLimits.columnCount.contains(parameters.columnCount))
        #expect(capabilities.hexPulseLatticeLimits.rowCount.contains(parameters.rowCount))
        #expect(capabilities.hexPulseLatticeLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func intentMapperCreatesSuperformulaMorphParametersForOrganicContourIntent() {
        var intent = PromptInterpreter.interpret("alien flower superformula organic emblem", seed: 24)
        intent.rendererFamily = .superformulaMorph
        intent.palette.hueBaseDegrees = -15
        intent.motion.speed = 20
        intent.composition.density = 1

        let capabilities = RendererCapabilities.superformulaMorph
        let renderParameters = IntentToRenderParametersMapper.renderParameters(
            from: intent,
            capabilities: capabilities
        )

        guard case .superformulaMorph(let parameters) = renderParameters else {
            Issue.record("Expected Superformula Morph render parameters")
            return
        }

        #expect(parameters.hueBaseDegrees == 345)
        #expect(capabilities.superformulaMorphLimits.contourCount.contains(parameters.contourCount))
        #expect(capabilities.superformulaMorphLimits.pointsPerContour.contains(parameters.pointsPerContour))
        #expect(capabilities.superformulaMorphLimits.speed.contains(parameters.speed))
        #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    }

    @Test func promptInterpreterSupportsJapaneseKeywords() {
        let intent = PromptInterpreter.interpret("紫のネオン 宇宙 粒子 高速", seed: 1)
        let parameters = PromptInterpreter.makeFieldLinesParameters(from: intent)

        #expect(intent.palette.hueBaseDegrees == 285)
        #expect(intent.motion.speed > 1.0)
        #expect(parameters.particleCount > FieldLinesParameters.feasibilityStudyDefault.particleCount)
        #expect(intent.moodTags.contains("neon"))
        #expect(intent.moodTags.contains("cosmic"))
    }

    @Test func promptInterpreterSelectsHexPulseLatticeForHoneycombKeywords() {
        #expect(PromptInterpreter.interpret("ネオンの六角格子ハニカム", seed: 1).rendererFamily == .hexPulseLattice)
        #expect(PromptInterpreter.interpret("sci-fi honeycomb circuit panel", seed: 1).rendererFamily == .hexPulseLattice)
    }

    @Test func promptInterpreterSelectsSuperformulaMorphForOrganicContourKeywords() {
        #expect(PromptInterpreter.interpret("異星の花 スーパーフォーミュラ", seed: 1).rendererFamily == .superformulaMorph)
        #expect(PromptInterpreter.interpret("alien flower organic emblem", seed: 1).rendererFamily == .superformulaMorph)
    }

    @Test func promptInterpreterSelectsRendererFamilyFromPromptSemantics() {
        #expect(PromptInterpreter.interpret("惑星間旅行のようなリング", seed: 1).rendererFamily == .orbital)
        #expect(PromptInterpreter.interpret("soft mist nebula drifting slowly", seed: 1).rendererFamily == .softVolumetric)
        #expect(PromptInterpreter.interpret("neon future city grid", seed: 1).rendererFamily == .gridCity)
        #expect(PromptInterpreter.interpret("金色のモアレ干渉パターン", seed: 1).rendererFamily == .interferenceField)
        #expect(PromptInterpreter.interpret("流体のマーブルと水の波紋", seed: 1).rendererFamily == .periodicNoise)
        #expect(PromptInterpreter.interpret("ライフゲームのセルオートマトン", seed: 1).rendererFamily == .cyclicAutomata)
        #expect(PromptInterpreter.interpret("蛍の群れが移動する光", seed: 1).rendererFamily == .agentSwarm)
        #expect(PromptInterpreter.interpret("万華鏡のような曼荼羅", seed: 1).rendererFamily == .kaleidoscope)
        #expect(PromptInterpreter.interpret("ボロノイの泡モザイク", seed: 1).rendererFamily == .voronoiFlow)
        #expect(PromptInterpreter.interpret("反応拡散の珊瑚模様", seed: 1).rendererFamily == .reactionDiffusion)
        #expect(PromptInterpreter.interpret("プラズマのラバランプ", seed: 1).rendererFamily == .plasmaField)
        #expect(PromptInterpreter.interpret("ワープトンネルのような惑星間旅行", seed: 1).rendererFamily == .harmonicTunnel)
        #expect(PromptInterpreter.interpret("レーザーのリサージュ曲線", seed: 1).rendererFamily == .lissajousWeave)
        #expect(PromptInterpreter.interpret("ひまわりの種の螺旋と開花", seed: 1).rendererFamily == .phyllotaxisBloom)
        #expect(PromptInterpreter.interpret("aurora ribbons and light trails", seed: 1).rendererFamily == .fieldLines)
    }

    @Test func promptInterpreterSelectsExpandedProceduralRendererFamilies() {
        #expect(PromptInterpreter.interpret("closed flow curl noise vector field", seed: 1).rendererFamily == .closedFlowParticles)
        #expect(PromptInterpreter.interpret("SDF raymarch tunnel through hyperspace", seed: 1).rendererFamily == .sdfTunnel)
        #expect(PromptInterpreter.interpret("Hydra video synth feedback echo", seed: 1).rendererFamily == .feedbackSynth)
        #expect(PromptInterpreter.interpret("Chladni plate standing wave", seed: 1).rendererFamily == .chladniPlate)
        #expect(PromptInterpreter.interpret("circuit trace signal routing", seed: 1).rendererFamily == .circuitTracer)
        #expect(PromptInterpreter.interpret("crystal lattice refractive geometry", seed: 1).rendererFamily == .crystalLattice)
        #expect(PromptInterpreter.interpret("electric storm lightning plasma arcs", seed: 1).rendererFamily == .electricStorm)
        #expect(PromptInterpreter.interpret("Fourier knot harmonic ribbon", seed: 1).rendererFamily == .fourierKnots)
        #expect(PromptInterpreter.interpret("growing network node graph edge growth", seed: 1).rendererFamily == .growingNetwork)
        #expect(PromptInterpreter.interpret("guilloche rose engine banknote ornament", seed: 1).rendererFamily == .guillocheRose)
        #expect(PromptInterpreter.interpret("instanced geometry triangle array", seed: 1).rendererFamily == .instancedGeometry)
        #expect(PromptInterpreter.interpret("laser ribbons nightclub beams", seed: 1).rendererFamily == .laserRibbons)
        #expect(PromptInterpreter.interpret("liquid metaballs soft blobs", seed: 1).rendererFamily == .metaballField)
        #expect(PromptInterpreter.interpret("moire rings optical beats", seed: 1).rendererFamily == .moireRings)
        #expect(PromptInterpreter.interpret("neon vortex energy funnel", seed: 1).rendererFamily == .neonVortex)
        #expect(PromptInterpreter.interpret("Penrose aperiodic tiling golden ratio", seed: 1).rendererFamily == .penroseTiling)
        #expect(PromptInterpreter.interpret("radial oscilloscope circular signal", seed: 1).rendererFamily == .radialOscilloscope)
        #expect(PromptInterpreter.interpret("rain curtain falling droplets", seed: 1).rendererFamily == .rainCurtain)
        #expect(PromptInterpreter.interpret("Truchet tiles arc maze", seed: 1).rendererFamily == .truchetFlow)
        #expect(PromptInterpreter.interpret("wave terrain topographic height field", seed: 1).rendererFamily == .waveTerrain)
    }

    @Test func stylePresetCombinesWithUserPrompt() {
        let combined = StylePreset.neonCity.combinedPrompt(with: "blue ribbon")

        #expect(combined.hasPrefix("blue ribbon,"))
        #expect(combined.contains(StylePreset.neonCity.promptFragment))
        #expect(StylePreset.calmFlow.combinedPrompt(with: "   ") == StylePreset.calmFlow.promptFragment)
    }

    @Test func stylePresetPromptInfluencesInterpreter() {
        let intent = PromptInterpreter.interpret(StylePreset.neonCity.combinedPrompt(with: "blue ribbon"), seed: 7)

        #expect(intent.moodTags.contains("neon"))
        #expect(intent.styleWeights.futureCity > 0.7)
        #expect(intent.motion.speed > 1.0)
        #expect(intent.elements.glowAmount > 0.8)
    }

    @Test func localVisualIntentProviderAppliesFollowUpCommands() throws {
        let provider = LocalVisualIntentProvider()
        let currentIntent = PromptInterpreter.interpret("calm blue lines", seed: 12)
        let editedIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "more particles and longer trails",
                seed: 12,
                currentIntent: currentIntent,
                capabilities: .fieldLines
            )
        )

        #expect(editedIntent.elements.particleAmount > currentIntent.elements.particleAmount)
        #expect(editedIntent.motion.trailLength > currentIntent.motion.trailLength)
        #expect(editedIntent.palette.hueBaseDegrees == currentIntent.palette.hueBaseDegrees)
    }

    @Test func localVisualIntentProviderUsesRequestedRendererFamily() throws {
        let provider = LocalVisualIntentProvider()
        let intent = provider.intent(
            for: VisualIntentRequest(
                prompt: "calm cosmic orbit",
                seed: 99,
                currentIntent: nil,
                capabilities: .orbital
            )
        )

        #expect(intent.rendererFamily == .orbital)

        let softIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "soft glowing mist",
                seed: 99,
                currentIntent: nil,
                capabilities: .softVolumetric
            )
        )

        #expect(softIntent.rendererFamily == .softVolumetric)

        let cityIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "future city grid",
                seed: 99,
                currentIntent: nil,
                capabilities: .gridCity
            )
        )

        #expect(cityIntent.rendererFamily == .gridCity)

        let interferenceIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "moire interference",
                seed: 99,
                currentIntent: nil,
                capabilities: .interferenceField
            )
        )

        #expect(interferenceIntent.rendererFamily == .interferenceField)

        let periodicIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "flowing marble water",
                seed: 99,
                currentIntent: nil,
                capabilities: .periodicNoise
            )
        )

        #expect(periodicIntent.rendererFamily == .periodicNoise)

        let automataIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "cellular automata reaction diffusion",
                seed: 99,
                currentIntent: nil,
                capabilities: .cyclicAutomata
            )
        )

        #expect(automataIntent.rendererFamily == .cyclicAutomata)

        let swarmIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "firefly swarm",
                seed: 99,
                currentIntent: nil,
                capabilities: .agentSwarm
            )
        )

        #expect(swarmIntent.rendererFamily == .agentSwarm)

        let kaleidoscopeIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "kaleidoscope mandala",
                seed: 99,
                currentIntent: nil,
                capabilities: .kaleidoscope
            )
        )

        #expect(kaleidoscopeIntent.rendererFamily == .kaleidoscope)

        let voronoiIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "voronoi mosaic bubbles",
                seed: 99,
                currentIntent: nil,
                capabilities: .voronoiFlow
            )
        )

        #expect(voronoiIntent.rendererFamily == .voronoiFlow)

        let reactionIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "reaction diffusion coral",
                seed: 99,
                currentIntent: nil,
                capabilities: .reactionDiffusion
            )
        )

        #expect(reactionIntent.rendererFamily == .reactionDiffusion)

        let plasmaIntent = provider.intent(
            for: VisualIntentRequest(
                prompt: "electric plasma lava lamp",
                seed: 99,
                currentIntent: nil,
                capabilities: .plasmaField
            )
        )

        #expect(plasmaIntent.rendererFamily == .plasmaField)
    }

    @Test func rendererCatalogCoversAllRendererFamiliesAndLoopContracts() {
        let capabilities = RendererCapabilities.catalog(preferred: .fieldLines)
        let catalogFamilies = capabilities.rendererCatalog.map(\.family)

        #expect(RendererFamily.allCases.count == 67)
        #expect(capabilities.supportedRendererFamilies == RendererFamily.allCases)
        #expect(catalogFamilies == RendererFamily.allCases)
        #expect(capabilities.rendererCatalog.filter { $0.loopContract.isExactlyPeriodic }.count == 65)
        #expect(capabilities.rendererCatalog.filter { !$0.loopContract.isExactlyPeriodic }.count == 2)

        for descriptor in capabilities.rendererCatalog {
            let hasFiniteTrailWarmup = descriptor.family == .fieldLines || descriptor.family == .orbital
            #expect(descriptor.loopContract.isExactlyPeriodic == !hasFiniteTrailWarmup)
            #expect(!descriptor.loopContract.phaseModel.isEmpty)
            #expect(!descriptor.loopContract.durationRule.isEmpty)
        }
    }

    @Test func proceduralRendererIntentMappingStaysWithinLimits() {
        let proceduralFamilies: [RendererFamily] = [
            .auroraCurtain,
            .cityLightsBokeh,
            .digitalSand,
            .inkInWater,
            .origamiTessellation,
            .sakuraDrift,
            .snowfallDepth,
            .solarCorona,
            .underwaterCaustics,
            .volumetricNebula,
            .bloomingCircuits,
            .cellularBloom,
            .chromaticBloom,
            .chladniPlate,
            .circuitTracer,
            .closedFlowParticles,
            .constellationDrift,
            .crystalLattice,
            .dataMesh,
            .electricStorm,
            .sdfTunnel,
            .feedbackSynth,
            .fireworksShow,
            .fluidNodes,
            .fourierKnots,
            .growingNetwork,
            .guillocheRose,
            .instancedGeometry,
            .labyrinthTrace,
            .laserRibbons,
            .luminousBubbles,
            .luminousStrings,
            .metaballField,
            .moireRings,
            .neonVortex,
            .particleFountain,
            .penroseTiling,
            .photonStreams,
            .pulseNetwork,
            .quantumFoam,
            .radialOscilloscope,
            .rainCurtain,
            .ribbonCascade,
            .scanlineTopography,
            .schoolingSwarm,
            .stardustVortex,
            .truchetFlow,
            .vortexLattice,
            .waveTerrain,
            .wireframeMorph
        ]

        var intent = PromptInterpreter.interpret("dense bright fast cosmic flowing geometric loop", seed: 25)
        intent.composition.density = 1
        intent.composition.depth = 1
        intent.motion.speed = 20
        intent.palette.hueBaseDegrees = -30

        for rendererFamily in proceduralFamilies {
            intent.rendererFamily = rendererFamily
            let capabilities = RendererCapabilities.capabilities(for: rendererFamily)
            let renderParameters = IntentToRenderParametersMapper.renderParameters(
                from: intent,
                capabilities: capabilities
            )

            switch renderParameters {
            case .auroraCurtain(let parameters),
                    .cityLightsBokeh(let parameters),
                    .digitalSand(let parameters),
                    .inkInWater(let parameters),
                    .origamiTessellation(let parameters),
                    .sakuraDrift(let parameters),
                    .snowfallDepth(let parameters),
                    .solarCorona(let parameters),
                    .underwaterCaustics(let parameters),
                    .volumetricNebula(let parameters),
                    .bloomingCircuits(let parameters),
                    .cellularBloom(let parameters),
                    .chladniPlate(let parameters),
                    .circuitTracer(let parameters),
                    .closedFlowParticles(let parameters),
                    .constellationDrift(let parameters),
                    .crystalLattice(let parameters),
                    .dataMesh(let parameters),
                    .electricStorm(let parameters),
                    .sdfTunnel(let parameters),
                    .feedbackSynth(let parameters),
                    .fireworksShow(let parameters),
                    .fluidNodes(let parameters),
                    .fourierKnots(let parameters),
                    .growingNetwork(let parameters),
                    .guillocheRose(let parameters),
                    .instancedGeometry(let parameters),
                    .laserRibbons(let parameters),
                    .luminousBubbles(let parameters),
                    .metaballField(let parameters),
                    .moireRings(let parameters),
                    .neonVortex(let parameters),
                    .particleFountain(let parameters),
                    .penroseTiling(let parameters),
                    .pulseNetwork(let parameters),
                    .radialOscilloscope(let parameters),
                    .rainCurtain(let parameters),
                    .ribbonCascade(let parameters),
                    .scanlineTopography(let parameters),
                    .schoolingSwarm(let parameters),
                    .truchetFlow(let parameters),
                    .waveTerrain(let parameters),
                    .wireframeMorph(let parameters):
                #expect(renderParameters.rendererFamily == rendererFamily)
                assertProceduralParameters(parameters, capabilities: capabilities)
            case .proceduralPattern(let family, let parameters):
                #expect(family == rendererFamily)
                assertProceduralParameters(parameters, capabilities: capabilities)
            default:
                Issue.record("Expected procedural render parameters for \(rendererFamily.displayName)")
            }
        }
    }

    @Test func visualIntentValidatorNormalizesUnsafeValues() throws {
        var intent = PromptInterpreter.interpret("fast flash storm", seed: 3)
        intent.schemaVersion = 1
        intent.palette.hueBaseDegrees = -20
        intent.palette.saturation = 2
        intent.composition.density = 4
        intent.motion.loopSeconds = 100
        intent.motion.speed = 20
        intent.motion.turbulence = 20
        intent.safety.flashIntensity = 2
        intent.safety.motionIntensity = 2

        let normalized = try VisualIntentValidator.normalized(intent, capabilities: .fieldLines)

        #expect(normalized.palette.hueBaseDegrees == 340)
        #expect(normalized.palette.saturation == 1)
        #expect(normalized.composition.density == 1)
        #expect(normalized.motion.loopSeconds == 30)
        #expect(normalized.motion.speed == PhotosensitivitySafetyPolicy.maxSpeedWhenPulsing)
        #expect(normalized.motion.turbulence == PhotosensitivitySafetyPolicy.maxTurbulenceWhenPulsing)
        #expect(normalized.safety.flashIntensity == PhotosensitivitySafetyPolicy.maxFlashIntensity)
        #expect(normalized.safety.motionIntensity == PhotosensitivitySafetyPolicy.maxMotionIntensity)
    }

    @Test func photosensitivityPolicyHonorsReducedMotion() throws {
        var intent = PromptInterpreter.interpret("fast neon particle storm", seed: 3)
        intent.motion.speed = 2
        intent.motion.turbulence = 2
        intent.safety.motionIntensity = 1

        let normalized = try VisualIntentValidator.normalized(
            intent,
            capabilities: .fieldLines,
            reducedMotion: true
        )
        guard case .fieldLines(let parameters) = IntentToRenderParametersMapper.renderParameters(
            from: normalized,
            reducedMotion: true
        ) else {
            Issue.record("Expected FieldLines render parameters")
            return
        }

        #expect(normalized.motion.speed == PhotosensitivitySafetyPolicy.reducedMotionMaxSpeed)
        #expect(normalized.motion.turbulence == PhotosensitivitySafetyPolicy.reducedMotionMaxTurbulence)
        #expect(normalized.safety.motionIntensity == PhotosensitivitySafetyPolicy.reducedMotionMaxMotionIntensity)
        #expect(parameters.speed == PhotosensitivitySafetyPolicy.reducedMotionMaxSpeed)
        #expect(parameters.turbulence == PhotosensitivitySafetyPolicy.reducedMotionMaxTurbulence)
    }

    @Test func visualIntentValidatorRejectsUnsupportedSchemaVersion() {
        var intent = PromptInterpreter.interpret("calm blue", seed: 1)
        intent.schemaVersion = 99

        #expect(throws: VisualIntentValidationError.unsupportedSchemaVersion(99)) {
            _ = try VisualIntentValidator.normalized(intent, capabilities: .fieldLines)
        }
    }

    @Test func exporterCreatesMovieFile() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 64,
            fps: 5,
            loopSeconds: 1.0,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperExporterTest-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exportedURL = try await GenerativeVideoExporter.export(project: project, to: outputURL) { _ in }
        let summary = try await ExportedVideoValidator.validate(url: exportedURL, expected: project.exportSettings)
        let attributes = try FileManager.default.attributesOfItem(atPath: exportedURL.path)
        let size = attributes[.size] as? NSNumber
        let expectedFrameCount = RenderClock(fps: 5, loopSeconds: 1.0).totalFrames

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect((size?.intValue ?? 0) > 0)
        #expect(summary.width == 64)
        #expect(summary.height == 64)
        #expect(summary.frameCount >= expectedFrameCount)
        #expect(summary.frameCount <= expectedFrameCount + 4)
        #expect(abs(summary.durationSeconds - 1.0) <= 2.0 / Double(project.exportSettings.fps))
        #expect(summary.nominalFrameRate > 0)
    }

    @Test func exporterCreatesOrbitalMovieFile() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .orbital, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 64,
            fps: 5,
            loopSeconds: 1.0,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperOrbitalExporterTest-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exportedURL = try await GenerativeVideoExporter.export(project: project, to: outputURL) { _ in }
        let summary = try await ExportedVideoValidator.validate(url: exportedURL, expected: project.exportSettings)

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect(summary.width == 64)
        #expect(summary.height == 64)
        #expect(summary.nominalFrameRate > 0)
    }

    @Test func exporterCreatesSoftVolumetricMovieFile() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .softVolumetric, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 64,
            fps: 5,
            loopSeconds: 1.0,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperSoftVolumetricExporterTest-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exportedURL = try await GenerativeVideoExporter.export(project: project, to: outputURL) { _ in }
        let summary = try await ExportedVideoValidator.validate(url: exportedURL, expected: project.exportSettings)

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect(summary.width == 64)
        #expect(summary.height == 64)
        #expect(summary.nominalFrameRate > 0)
    }

    @Test func exporterCreatesGridCityMovieFile() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newProject(rendererFamily: .gridCity, appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 64,
            height: 64,
            fps: 5,
            loopSeconds: 1.0,
            codec: .h264,
            quality: .draft,
            warmupLoops: 0
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperGridCityExporterTest-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let exportedURL = try await GenerativeVideoExporter.export(project: project, to: outputURL) { _ in }
        let summary = try await ExportedVideoValidator.validate(url: exportedURL, expected: project.exportSettings)

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect(summary.width == 64)
        #expect(summary.height == 64)
        #expect(summary.nominalFrameRate > 0)
    }

    @Test func exporterHonorsCancellation() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            return
        }

        var project = WallpaperProject.newFieldLinesProject(appVersion: "test")
        project.seed = 42
        project.exportSettings = ExportSettings(
            width: 128,
            height: 128,
            fps: 30,
            loopSeconds: 10,
            codec: .h264,
            quality: .draft,
            warmupLoops: 1
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RioVideoWallpaperExporterCancellationTest-\(UUID().uuidString).mp4")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let task = Task {
            try await GenerativeVideoExporter.export(project: project, to: outputURL) { _ in }
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}

private func assertProceduralParameters(
    _ parameters: ProceduralPatternParameters,
    capabilities: RendererCapabilities
) {
    let limits = capabilities.proceduralPatternLimits

    #expect(limits.elementCount.contains(parameters.elementCount))
    #expect(limits.samplesPerElement.contains(parameters.samplesPerElement))
    #expect(limits.harmonicA.contains(parameters.harmonicA))
    #expect(limits.harmonicB.contains(parameters.harmonicB))
    #expect(limits.fadeAlpha.contains(parameters.fadeAlpha))
    #expect(limits.scale.contains(parameters.scale))
    #expect(limits.modulation.contains(parameters.modulation))
    #expect(limits.depth.contains(parameters.depth))
    #expect(limits.feedback.contains(parameters.feedback))
    #expect(parameters.hueBaseDegrees >= 0)
    #expect(parameters.hueBaseDegrees < 360)
    #expect(limits.hueSpreadDegrees.contains(parameters.hueSpreadDegrees))
    #expect(limits.saturation.contains(parameters.saturation))
    #expect(limits.brightness.contains(parameters.brightness))
    #expect(parameters.brightness <= PhotosensitivitySafetyPolicy.maxBrightness)
    #expect(limits.pointAlpha.contains(parameters.pointAlpha))
    #expect(limits.pointSize.contains(parameters.pointSize))
    #expect(limits.speed.contains(parameters.speed))
    #expect(limits.rotation.contains(parameters.rotation))
}
