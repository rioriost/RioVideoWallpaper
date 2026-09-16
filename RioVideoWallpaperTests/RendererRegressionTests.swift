import AVFoundation
import Foundation
import Metal
import Testing
@testable import RioVideoWallpaper

@Suite(.serialized)
struct RendererRegressionTests {
    @Test func loopContractsDistinguishGeometryFromTrailSteadyState() {
        for descriptor in RendererCapabilities.catalog(preferred: .fieldLines).rendererCatalog {
            let accumulates = descriptor.family == .fieldLines || descriptor.family == .orbital
            #expect(descriptor.loopContract.isExactlyPeriodic == !accumulates)
        }
    }

    @Test func unwrappedClockDoesNotMakePeriodicityTestsTautological() {
        let clock = RenderClock(fps: 30, loopSeconds: 10, wrapsTime: false)
        #expect(clock.phase(frameIndex: clock.totalFrames) == 2 * Double.pi)
        #expect(clock.phase(frameIndex: -clock.totalFrames) == -2 * Double.pi)
        #expect(RenderClock(fps: Int.max, loopSeconds: .infinity).totalFrames > 0)
    }

    @Test func allFamiliesHavePeriodicVertexSignalsBeforeClockWrapping() throws {
        let context = try RendererTestContext()
        for family in RendererFamily.allCases {
            for seed: UInt64 in [0, 42] {
                for speed in [0.5, 1.0, 2.5] {
                    let parameters = representativeParameters(family).settingSpeed(speed)
                    let clock = RenderClock(fps: 30, loopSeconds: 10, wrapsTime: false, frameOffset: 41.1)
                    let first = context.renderer.sampleVertices(
                        parameters: parameters, seed: seed, frameIndex: 0, clock: clock, drawableSize: context.size
                    )
                    let next = context.renderer.sampleVertices(
                        parameters: parameters, seed: seed, frameIndex: clock.totalFrames, clock: clock, drawableSize: context.size
                    )
                    #expect(first.count == next.count, "\(family) seed \(seed) speed \(speed): vertex count")
                    var maximumError: Float = 0
                    for (a, b) in zip(first, next) {
                        #expect(a.position.x.isFinite && a.position.y.isFinite && a.pointSize.isFinite, "\(family)")
                        let colorError = max(abs(a.color.x - b.color.x), abs(a.color.y - b.color.y),
                                             abs(a.color.z - b.color.z), abs(a.color.w - b.color.w))
                        maximumError = max(maximumError, colorError, abs(a.pointSize - b.pointSize))
                        let visible = max(a.color.x, a.color.y, a.color.z) * a.color.w > 0.001 ||
                            max(b.color.x, b.color.y, b.color.z) * b.color.w > 0.001
                        if visible {
                            maximumError = max(maximumError, abs(a.position.x - b.position.x), abs(a.position.y - b.position.y))
                        }
                    }
                    #expect(maximumError < 0.02, "\(family) seed \(seed) speed \(speed): unwrapped error \(maximumError)")
                }
            }
        }
    }

    @Test func allFamiliesHaveContinuousBoundaryImages() throws {
        let context = try RendererTestContext()
        for family in RendererFamily.allCases {
            for seed: UInt64 in [0, 42] {
                let parameters = representativeParameters(family)
                let before = RenderClock(fps: 30, loopSeconds: 10, wrapsTime: false, frameOffset: 299.999)
                let after = RenderClock(fps: 30, loopSeconds: 10, wrapsTime: false, frameOffset: 0.001)
                let left = try context.draw(parameters, seed: seed, clock: before)
                let right = try context.draw(parameters, seed: seed, clock: after)
                let error = meanRGBDifference(left, right)
                #expect(error < 0.8, "\(family) seed \(seed): seam RGB mean difference \(error)/255")
            }
        }
    }

    @Test func fireworksEmptyFrameClearsPreviouslyRenderedPixels() throws {
        let context = try RendererTestContext()
        context.fill([0, 0, 255, 255])
        let parameters = RenderParameters.fireworksShow(.defaultParameters(for: .fireworksShow))
        let black = try context.draw(parameters, frame: 0)
        #expect(isOpaqueBlack(black))
        _ = try context.draw(parameters, frame: 30)
        let boundary = try context.draw(parameters, frame: 0)
        #expect(boundary == black)

        let rgbaSession = try GenerativeRenderSession(device: context.device, colorPixelFormat: .rgba8Unorm)
        let rgbaTexture = try rgbaSession.render(
            parameters: parameters, seed: 42, frameIndex: 0, settings: .standard,
            drawableSize: context.size, commandQueue: context.queue
        )
        #expect(rgbaTexture.pixelFormat == .rgba8Unorm)
        #expect(isOpaqueBlack(context.bytes(rgbaTexture)))
    }

    @Test func logicalUpdatesAreIndependentOfPresentationAndSeekHistory() throws {
        let context = try RendererTestContext()
        var settings = ExportSettings.standard
        settings.width = 64
        settings.height = 64
        settings.fps = 5
        settings.loopSeconds = 1
        settings.warmupLoops = 1
        for parameters in [quietFieldLines(), quietOrbital()] {
            let sequential = try GenerativeRenderSession(device: context.device)
            let skipped = try GenerativeRenderSession(device: context.device)
            for frame in 0...9 {
                _ = try sequential.render(parameters: parameters, seed: 42, frameIndex: frame,
                                          settings: settings, drawableSize: context.size, commandQueue: context.queue)
            }
            let reference = try sequential.render(parameters: parameters, seed: 42, frameIndex: 9,
                                                  settings: settings, drawableSize: context.size, commandQueue: context.queue)
            let expected = context.bytes(reference)
            var frames: [Int] = []
            let result = try skipped.render(parameters: parameters, seed: 42, frameIndex: 9,
                                             settings: settings, drawableSize: context.size, commandQueue: context.queue) {
                frames.append($0)
            }
            #expect(frames == Array(-5...9))
            #expect(context.bytes(result) == expected)
            let repeated = try skipped.render(parameters: parameters, seed: 42, frameIndex: 9,
                                               settings: settings, drawableSize: context.size, commandQueue: context.queue) {
                Issue.record("A repeated presentation must not advance frame \($0)")
            }
            #expect(context.bytes(repeated) == expected)
            let sought = try skipped.render(parameters: parameters, seed: 42, frameIndex: 3,
                                             settings: settings, drawableSize: context.size, commandQueue: context.queue)
            let soughtBytes = context.bytes(sought)
            sequential.reset()
            let rebuilt = try sequential.render(parameters: parameters, seed: 42, frameIndex: 3,
                                                 settings: settings, drawableSize: context.size, commandQueue: context.queue)
            #expect(context.bytes(rebuilt) == soughtBytes)
            let changed = parameters.settingSpeed(1.7)
            let changedTexture = try skipped.render(parameters: changed, seed: 43, frameIndex: 3,
                                                      settings: settings, drawableSize: context.size, commandQueue: context.queue)
            let changedBytes = context.bytes(changedTexture)
            let changedReference = try sequential.render(parameters: changed, seed: 43, frameIndex: 3,
                                                          settings: settings, drawableSize: context.size, commandQueue: context.queue)
            #expect(context.bytes(changedReference) == changedBytes)
        }
    }

    @Test func sameTargetSeeksHaveDistinctIdentityAndOcclusionDoesNotSkipTime() {
        let clock = RenderClock(fps: 30, loopSeconds: 10)
        var playback = PreviewPlaybackState()
        playback.reset(at: 100)
        let first = PreviewSeekRequest(frameIndex: 0)
        let appliedFirst = playback.apply(first, at: 100, clock: clock)
        #expect(appliedFirst)
        #expect(playback.frame(at: 102, clock: clock) == 60)
        let repeated = playback.apply(first, at: 102, clock: clock)
        #expect(!repeated)
        playback.setPlaying(false, at: 102, clock: clock)
        let appliedAgain = playback.apply(PreviewSeekRequest(frameIndex: 0), at: 102, clock: clock)
        #expect(appliedAgain)
        #expect(playback.frame(at: 110, clock: clock) == 0)
        playback.setPlaying(true, at: 110, clock: clock)
        playback.setSuspended(true, at: 112, clock: clock)
        playback.setSuspended(false, at: 212, clock: clock)
        #expect(playback.frame(at: 213, clock: clock) == 90)
        let cleared = playback.apply(nil, at: 213, clock: clock)
        #expect(!cleared)
        let afterClear = playback.apply(PreviewSeekRequest(frameIndex: 0), at: 213, clock: clock)
        #expect(afterClear)
        #expect(playback.frame(at: 213, clock: clock) == 0)
        playback.rebase(at: 423, clock: clock)
        #expect(playback.frame(at: 423, clock: clock) == 0)
    }

    @Test func cancelledPreviewWarmupResetsBeforeTheNextRequest() throws {
        let context = try RendererTestContext()
        let session = try GenerativeRenderSession(device: context.device)
        var settings = ExportSettings.standard
        settings.fps = 5
        settings.loopSeconds = 1
        let job = PreviewRenderJob()
        #expect(throws: CancellationError.self) {
            _ = try session.render(parameters: quietFieldLines(), seed: 42, frameIndex: 0,
                                   settings: settings, drawableSize: context.size, commandQueue: context.queue,
                                   checkCancellation: job.checkCancellation) { _ in
                job.cancel()
            }
        }
        #expect(session.sequence.lastFrameIndex == nil)
        var frames: [Int] = []
        _ = try session.render(parameters: quietFieldLines(), seed: 42, frameIndex: 0,
                               settings: settings, drawableSize: context.size, commandQueue: context.queue) {
            frames.append($0)
        }
        #expect(frames == Array(-5...0))
    }

    @Test func readinessFailureAndFinalizationCancellationTerminate() throws {
        let writer = FakeExportWriter()
        var waits = 0
        #expect(throws: ExportError.self) {
            try ExportWriterWait.untilReady(writer: writer, isReady: { false }, wait: {
                waits += 1
                writer.status = .failed
            })
        }
        #expect(waits == 1)
        writer.status = .writing
        var checks = 0
        #expect(throws: CancellationError.self) {
            try ExportWriterWait.finish(writer: writer, start: { _ in }, checkCancellation: {
                checks += 1
                if checks == 2 { throw CancellationError() }
            })
        }
        #expect(checks == 2)
    }

    @Test func invalidExportDimensionsAndTimingNeverOverflow() throws {
        var settings = ExportSettings.standard
        settings.width = Int.max
        #expect(throws: ExportSettingsError.self) { try settings.validatedForExport() }
        #expect(throws: ExportSettingsError.self) { try settings.estimatedBitRate() }
        #expect(settings.normalizedForExport().width == ExportSettings.maximumDimension)
        settings = .standard
        settings.fps = Int.max
        settings.warmupLoops = Int.max
        settings.loopSeconds = .infinity
        #expect(throws: ExportSettingsError.self) { try settings.validatedForExport() }
        let normalized = settings.normalizedForExport()
        #expect(normalized.fps == ExportSettings.maximumFPS)
        #expect(normalized.warmupLoops == ExportSettings.maximumWarmupLoops)
        #expect(normalized.loopSeconds.isFinite)
        for preset in ExportPreset.allCases {
            if let settings = preset.baseSettings {
                _ = try settings.validatedForExport()
                #expect(try settings.estimatedBitRate() > 0)
            }
        }
    }

    @Test func loopDurationBoundsPreserveLongRendererCycles() throws {
        for duration in [56.0, 560.0, 600.0] {
            var settings = ExportSettings.standard
            settings.loopSeconds = duration
            let validated = try settings.validatedForExport()
            #expect(validated.loopSeconds == duration)
            #expect(settings.normalizedForExport().loopSeconds == duration)
            let clock = RenderClock(fps: validated.fps, loopSeconds: duration)
            #expect(clock.durationSeconds == duration)
            #expect(clock.totalFrames == Int(duration * Double(validated.fps)))
        }
        var unsupported = ExportSettings.standard
        unsupported.loopSeconds = 600.01
        #expect(throws: ExportSettingsError.self) { try unsupported.validatedForExport() }
        #expect(unsupported.normalizedForExport().loopSeconds == 600)
        let boundedClock = RenderClock(fps: Int.max, loopSeconds: .greatestFiniteMagnitude)
        #expect(boundedClock.totalFrames == 72_000)
        #expect(boundedClock.warmupFrameIndices(warmupLoops: Int.max).count == 288_000)
    }

    @Test func failedAndCancelledTransactionsPreserveExistingMovie() async throws {
        let directory = try regressionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("existing.mp4")
        let original = Data("original".utf8)
        try original.write(to: output)
        await #expect(throws: ProbeFailure.self) {
            _ = try await ExportFileTransaction.write(to: output) { stage in
                try Data("incomplete".utf8).write(to: stage)
                throw ProbeFailure.injected
            }
        }
        #expect(try Data(contentsOf: output) == original)
        let cancelled = Task {
            try await ExportFileTransaction.write(to: output) { stage in
                try Data("complete but cancelled".utf8).write(to: stage)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        await #expect(throws: CancellationError.self) { _ = try await cancelled.value }
        #expect(try Data(contentsOf: output) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["existing.mp4"])
    }

    @Test func tinyExportsHaveExactSampleCountsAndReplaceOnlyOnSuccess() async throws {
        let directory = try regressionDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for codec in VideoCodec.allCases {
            var project = WallpaperProject.newProject(rendererFamily: .gridCity, appVersion: "regression")
            project.seed = 42
            project.exportSettings = ExportSettings(width: 64, height: 64, fps: 5, loopSeconds: 0.6,
                                                    codec: codec, quality: .draft, warmupLoops: 0)
            let output = directory.appendingPathComponent("\(codec.rawValue).mp4")
            try Data("old version".utf8).write(to: output)
            _ = try await GenerativeVideoExporter.export(project: project, to: output) { _ in }
            let summary = try await ExportedVideoValidator.validate(url: output, expected: project.exportSettings)
            #expect(summary.frameCount == 3)
            #expect(abs(summary.durationSeconds - 0.6) < 0.02)
        }
    }
}

private final class FakeExportWriter: ExportWriterState {
    var status = AVAssetWriter.Status.writing
    var error: Error? { nil }
}

private enum ProbeFailure: Error { case injected }

private func regressionDirectory() throws -> URL {
    let base = ProcessInfo.processInfo.environment["RIO_TEST_ARTIFACT_ROOT"] ?? FileManager.default.currentDirectoryPath
    let directory = URL(fileURLWithPath: base).appendingPathComponent(".renderer-regression-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func quietFieldLines() -> RenderParameters {
    var p = FieldLinesParameters.feasibilityStudyDefault
    p.bandCount = 1
    p.pointsPerBand = 120
    p.particleCount = 0
    p.lineAlpha = 0.04
    p.lineWeight = 0.5
    p.fadeAlpha = 0.1
    return .fieldLines(p)
}

private func quietOrbital() -> RenderParameters {
    var p = OrbitalParameters.defaultParameters
    p.orbitCount = 1
    p.pointsPerOrbit = 120
    p.satelliteCount = 2
    p.orbitAlpha = 0.04
    return .orbital(p)
}

private func representativeParameters(_ family: RendererFamily) -> RenderParameters {
    let classics: Set<RendererFamily> = [.fieldLines, .orbital, .softVolumetric, .gridCity,
        .interferenceField, .periodicNoise, .cyclicAutomata, .agentSwarm, .kaleidoscope,
        .voronoiFlow, .reactionDiffusion, .plasmaField, .harmonicTunnel, .lissajousWeave,
        .phyllotaxisBloom, .hexPulseLattice, .superformulaMorph]
    if classics.contains(family) { return .defaultParameters(for: family) }
    var p = ProceduralPatternParameters.defaultParameters(for: family)
    p.elementCount = min(p.elementCount, 24)
    p.samplesPerElement = min(p.samplesPerElement, 96)
    p.harmonicA = 4
    p.harmonicB = 9
    p.modulation = 0.73
    p.depth = 0.61
    return .proceduralPattern(family, p)
}

private func meanRGBDifference(_ first: [UInt8], _ second: [UInt8]) -> Double {
    var total = 0
    for i in first.indices where i % 4 != 3 {
        total += abs(Int(first[i]) - Int(second[i]))
    }
    return Double(total) / Double(first.count / 4 * 3)
}

private func isOpaqueBlack(_ bytes: [UInt8]) -> Bool {
    bytes.indices.allSatisfy { bytes[$0] == ($0 % 4 == 3 ? 255 : 0) }
}

private final class RendererTestContext {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let renderer: GenerativeFrameRenderer
    let texture: MTLTexture
    let size = CGSize(width: 64, height: 64)

    init() throws {
        device = try #require(MTLCreateSystemDefaultDevice())
        queue = try #require(device.makeCommandQueue())
        renderer = try GenerativeFrameRenderer(device: device, colorPixelFormat: .bgra8Unorm)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        texture = try #require(device.makeTexture(descriptor: descriptor))
    }

    func fill(_ bgra: [UInt8]) {
        let pixels = Array(repeating: bgra, count: 4096).flatMap { $0 }
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 256)
        }
    }

    func bytes(_ texture: MTLTexture) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 16384)
        texture.getBytes(&result, bytesPerRow: 256, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
        return result
    }

    func draw(
        _ parameters: RenderParameters, seed: UInt64 = 42,
        clock: RenderClock = RenderClock(fps: 30, loopSeconds: 10), frame: Int = 0
    ) throws -> [UInt8] {
        try autoreleasepool {
            renderer.resetAccumulation()
            let command = try #require(queue.makeCommandBuffer())
            renderer.render(parameters: parameters, seed: seed, frameIndex: frame, clock: clock,
                            drawableSize: size, outputTexture: texture, commandBuffer: command)
            try renderer.checkEncoding()
            command.commit()
            command.waitUntilCompleted()
            #expect(command.status == .completed)
            if let error = command.error { throw error }
            return bytes(texture)
        }
    }
}
