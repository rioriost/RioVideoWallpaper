//
//  GenerativeVideoExporter.swift
//  RioVideoWallpaper
//

import AVFoundation
import CoreVideo
import Foundation
import Metal

enum GenerativeVideoExporter {
    static func export(
        project: WallpaperProject,
        to outputURL: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let settings = try project.exportSettings.validatedForExport()
        let exportedURL = try await ExportFileTransaction.write(to: outputURL) { stagingURL in
            let exportTask = Task.detached(priority: .userInitiated) {
                try exportSynchronously(project: project, to: stagingURL, progress: progress)
            }
            _ = try await withTaskCancellationHandler {
                try await exportTask.value
            } onCancel: {
                exportTask.cancel()
            }
            try Task.checkCancellation()
            _ = try await ExportedVideoValidator.validate(url: stagingURL, expected: settings)
            try Task.checkCancellation()
        }
        progress(1.0)
        return exportedURL
    }

    private static func exportSynchronously(
        project: WallpaperProject,
        to outputURL: URL,
        progress: (Double) -> Void
    ) throws -> URL {
        try Task.checkCancellation()

        let settings = try project.exportSettings.validatedForExport()
        let clock = RenderClock(fps: settings.fps, loopSeconds: settings.loopSeconds)

        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw ExportError.metalUnavailable
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: try settings.videoOutputSettings)
        input.expectsMediaDataInRealTime = false
        defer {
            if writer.status == .writing || writer.status == .unknown {
                writer.cancelWriting()
            }
        }

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: settings.pixelBufferAttributes
        )

        guard writer.canAdd(input) else {
            throw ExportError.writerInputRejected
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw ExportError.pixelBufferPoolUnavailable
        }

        var textureCache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        guard cacheStatus == kCVReturnSuccess, let textureCache else {
            throw ExportError.textureCacheCreationFailed(cacheStatus)
        }

        let renderer = try GenerativeRenderSession(device: device)

        let drawableSize = CGSize(width: settings.width, height: settings.height)
        let accumulates = project.renderParameters.rendererFamily == .fieldLines ||
            project.renderParameters.rendererFamily == .orbital
        let warmupCount = accumulates ? clock.warmupFrameIndices(warmupLoops: settings.warmupLoops).count : 0
        let totalWork = max(1, warmupCount + clock.totalFrames)
        var completedWork = 0

        for frameIndex in clock.exportFrameIndices() {
            try ExportWriterWait.untilReady(writer: writer, isReady: { input.isReadyForMoreMediaData })
            let pixelBuffer = try autoreleasepool {
                try renderFrame(
                    parameters: project.renderParameters, seed: project.seed, frameIndex: frameIndex,
                    settings: settings, drawableSize: drawableSize,
                    pixelBufferPool: pixelBufferPool, textureCache: textureCache,
                    renderer: renderer, commandQueue: commandQueue
                ) { _ in
                    completedWork += 1
                    progress(0.95 * Double(completedWork) / Double(totalWork))
                }
            }
            try Task.checkCancellation()
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(settings.fps))
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw ExportError.appendFailed(writer.error)
            }
        }

        try Task.checkCancellation()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(clock.totalFrames), timescale: CMTimeScale(settings.fps)))
        input.markAsFinished()
        try ExportWriterWait.finish(writer: writer) { completion in
            writer.finishWriting(completionHandler: completion)
        }
        return outputURL
    }

    @discardableResult
    private static func renderFrame(
        parameters: RenderParameters,
        seed: UInt64,
        frameIndex: Int,
        settings: ExportSettings,
        drawableSize: CGSize,
        pixelBufferPool: CVPixelBufferPool,
        textureCache: CVMetalTextureCache,
        renderer: GenerativeRenderSession,
        commandQueue: MTLCommandQueue,
        didRenderFrame: (Int) -> Void
    ) throws -> CVPixelBuffer {
        try Task.checkCancellation()

        var maybePixelBuffer: CVPixelBuffer?
        let bufferStatus = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &maybePixelBuffer)
        guard bufferStatus == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            throw ExportError.pixelBufferCreationFailed(bufferStatus)
        }

        var maybeTexture: CVMetalTexture?
        let textureStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            Int(drawableSize.width),
            Int(drawableSize.height),
            0,
            &maybeTexture
        )
        guard textureStatus == kCVReturnSuccess,
              let cvTexture = maybeTexture,
              let texture = CVMetalTextureGetTexture(cvTexture) else {
            throw ExportError.pixelBufferTextureCreationFailed(textureStatus)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ExportError.commandBufferCreationFailed
        }

        let renderedTexture = try renderer.render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            settings: settings,
            drawableSize: drawableSize,
            commandQueue: commandQueue,
            didRenderFrame: didRenderFrame
        )
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].storeAction = .store
        try renderer.present(renderedTexture, descriptor: descriptor, commandBuffer: commandBuffer)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw ExportError.gpuFailed(error)
        }

        return pixelBuffer
    }
}

private extension ExportSettings {
    var videoOutputSettings: [String: Any] {
        get throws {
            return [
                AVVideoCodecKey: codec.avVideoCodecType,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: try estimatedBitRate(),
                    AVVideoExpectedSourceFrameRateKey: fps,
                    AVVideoAllowFrameReorderingKey: false
                ]
            ]
        }
    }

    var pixelBufferAttributes: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
    }

}

private extension VideoCodec {
    var avVideoCodecType: AVVideoCodecType {
        switch self {
        case .h264:
            return .h264
        case .hevc:
            return .hevc
        }
    }
}

enum ExportError: LocalizedError {
    case unsupportedRenderer
    case metalUnavailable
    case writerInputRejected
    case writerFailed(Error?)
    case pixelBufferPoolUnavailable
    case textureCacheCreationFailed(CVReturn)
    case pixelBufferCreationFailed(CVReturn)
    case pixelBufferTextureCreationFailed(CVReturn)
    case commandBufferCreationFailed
    case gpuFailed(Error)
    case appendFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .unsupportedRenderer:
            return "This renderer is not supported for export yet."
        case .metalUnavailable:
            return "Metal is not available on this Mac."
        case .writerInputRejected:
            return "The video writer rejected the requested output settings."
        case .writerFailed(let error):
            return error?.localizedDescription ?? "The video writer failed."
        case .pixelBufferPoolUnavailable:
            return "The video pixel buffer pool could not be created."
        case .textureCacheCreationFailed(let status):
            return "The Metal texture cache could not be created. CVReturn: \(status)"
        case .pixelBufferCreationFailed(let status):
            return "A video pixel buffer could not be created. CVReturn: \(status)"
        case .pixelBufferTextureCreationFailed(let status):
            return "A Metal texture could not be created for the video pixel buffer. CVReturn: \(status)"
        case .commandBufferCreationFailed:
            return "A Metal command buffer could not be created."
        case .gpuFailed(let error):
            return error.localizedDescription
        case .appendFailed(let error):
            return error?.localizedDescription ?? "A rendered frame could not be appended to the video."
        }
    }
}
