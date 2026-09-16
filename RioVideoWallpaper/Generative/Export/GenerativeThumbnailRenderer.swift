//
//  GenerativeThumbnailRenderer.swift
//  RioVideoWallpaper
//

import AppKit
import Foundation
import MetalKit

enum GenerativeThumbnailRenderer {
    enum ThumbnailError: Error {
        case metalUnavailable
        case commandQueueCreationFailed
        case commandBufferCreationFailed
        case textureCreationFailed
        case imageCreationFailed
        case invalidSize
    }

    static func renderPNG(
        project: WallpaperProject,
        size: CGSize = CGSize(width: 320, height: 200)
    ) throws -> Data {
        guard size.width.isFinite, size.height.isFinite,
              size.width >= 2, size.height >= 2,
              size.width <= CGFloat(ExportSettings.maximumDimension),
              size.height <= CGFloat(ExportSettings.maximumDimension) else {
            throw ThumbnailError.invalidSize
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw ThumbnailError.metalUnavailable
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw ThumbnailError.commandQueueCreationFailed
        }

        let pixelWidth = max(1, Int(size.width.rounded(.toNearestOrAwayFromZero)))
        let pixelHeight = max(1, Int(size.height.rounded(.toNearestOrAwayFromZero)))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw ThumbnailError.textureCreationFailed
        }

        let renderer = try GenerativeRenderSession(device: device)
        let settings = try project.exportSettings.validatedForExport()
        let clock = RenderClock(fps: settings.fps, loopSeconds: settings.loopSeconds)
        let frame = try renderer.render(parameters: project.renderParameters, seed: project.seed,
                                        frameIndex: clock.totalFrames / 3, settings: settings,
                                        drawableSize: CGSize(width: pixelWidth, height: pixelHeight),
                                        commandQueue: commandQueue)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ThumbnailError.commandBufferCreationFailed
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = outputTexture
        pass.colorAttachments[0].storeAction = .store
        try renderer.present(frame, descriptor: pass, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error { throw error }

        return try pngData(from: outputTexture, width: pixelWidth, height: pixelHeight)
    }

    static func renderPNG(project: WallpaperProject, to outputURL: URL) throws {
        let data = try renderPNG(project: project)
        try data.write(to: outputURL, options: .atomic)
    }

    private static func pngData(from texture: MTLTexture, width: Int, height: Int) throws -> Data {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)

        texture.getBytes(
            &bytes,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw ThumbnailError.imageCreationFailed
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ThumbnailError.imageCreationFailed
        }
        return data
    }
}
