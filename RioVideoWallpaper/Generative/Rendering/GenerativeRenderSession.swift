import Foundation
import Metal

struct RenderFrameSequence {
    private(set) var lastFrameIndex: Int?

    mutating func reset() {
        lastFrameIndex = nil
    }

    func frames(
        through target: Int, clock: RenderClock, warmupLoops: Int, accumulates: Bool
    ) -> Range<Int> {
        precondition(target >= 0 && target < Int.max)
        if lastFrameIndex == target { return target..<target }
        guard accumulates else { return target..<(target + 1) }
        let start = lastFrameIndex.map { $0 + 1 }
            ?? clock.warmupFrameIndices(warmupLoops: warmupLoops).lowerBound
        return start..<(target + 1)
    }

    mutating func didRender(_ frame: Int) {
        lastFrameIndex = frame
    }
}

/// Serial logical-frame updates; presenting the resulting texture never advances the simulation.
final class GenerativeRenderSession {
    private struct Scene: Equatable {
        var parameters: RenderParameters
        var seed: UInt64
        var clock: RenderClock
        var warmupLoops: Int
        var width: Int
        var height: Int
    }

    private let device: MTLDevice
    private let colorPixelFormat: MTLPixelFormat
    private let renderer: GenerativeFrameRenderer
    private let copyPipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private var scene: Scene?
    private var texture: MTLTexture?
    private(set) var sequence = RenderFrameSequence()

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        self.device = device
        self.colorPixelFormat = colorPixelFormat
        renderer = try GenerativeFrameRenderer(device: device, colorPixelFormat: colorPixelFormat)
        let library = try device.makeDefaultLibrary(bundle: .main)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fieldLinesFullscreenVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "fieldLinesCopyFragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        copyPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let sampling = MTLSamplerDescriptor()
        sampling.minFilter = .nearest
        sampling.magFilter = .nearest
        guard let sampler = device.makeSamplerState(descriptor: sampling) else {
            throw RendererError.samplerCreationFailed
        }
        self.sampler = sampler
    }

    func reset() {
        sequence.reset()
        renderer.resetAccumulation()
    }

    @discardableResult
    func render(
        parameters: RenderParameters, seed: UInt64, frameIndex: Int,
        settings: ExportSettings, drawableSize: CGSize, commandQueue: MTLCommandQueue,
        checkCancellation: () throws -> Void = { try Task.checkCancellation() },
        didRenderFrame: (Int) -> Void = { _ in }
    ) throws -> MTLTexture {
        guard frameIndex >= 0, frameIndex < Int.max,
              drawableSize.width.isFinite, drawableSize.height.isFinite,
              drawableSize.width >= 2, drawableSize.height >= 2,
              drawableSize.width <= CGFloat(ExportSettings.maximumDimension),
              drawableSize.height <= CGFloat(ExportSettings.maximumDimension) else {
            throw ExportSettingsError.unsupportedDimensions
        }
        let settings = try settings.validatedForExport()
        let clock = RenderClock(fps: settings.fps, loopSeconds: settings.loopSeconds)
        let width = Int(drawableSize.width.rounded())
        let height = Int(drawableSize.height.rounded())
        let newScene = Scene(parameters: parameters, seed: seed, clock: clock,
                             warmupLoops: settings.warmupLoops, width: width, height: height)
        if scene != newScene {
            reset()
            scene = newScene
        }
        if let lastFrame = sequence.lastFrameIndex, frameIndex < lastFrame {
            reset()
        }
        if texture == nil || texture?.width != width || texture?.height != height {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: colorPixelFormat, width: width, height: height, mipmapped: false
            )
            descriptor.storageMode = .shared
            descriptor.usage = [.renderTarget, .shaderRead]
            texture = device.makeTexture(descriptor: descriptor)
        }
        guard let texture else { throw RenderEncodingError.textureCreationFailed }
        let accumulates = parameters.rendererFamily == .fieldLines || parameters.rendererFamily == .orbital
        let frames = sequence.frames(through: frameIndex, clock: clock,
                                     warmupLoops: settings.warmupLoops, accumulates: accumulates)
        do {
            for frame in frames {
                try checkCancellation()
                try autoreleasepool {
                    guard let command = commandQueue.makeCommandBuffer() else {
                        throw RenderEncodingError.commandBufferCreationFailed
                    }
                    renderer.render(parameters: parameters, seed: seed, frameIndex: frame,
                                    clock: clock, drawableSize: CGSize(width: width, height: height),
                                    outputTexture: texture, commandBuffer: command)
                    try renderer.checkEncoding()
                    command.commit()
                    command.waitUntilCompleted()
                    if let error = command.error { throw error }
                }
                sequence.didRender(frame)
                didRenderFrame(frame)
            }
            try checkCancellation()
        } catch {
            reset()
            throw error
        }
        return texture
    }

    func present(
        _ texture: MTLTexture, descriptor: MTLRenderPassDescriptor,
        commandBuffer: MTLCommandBuffer
    ) throws {
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = GenerativeRenderStyle.backgroundColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw RenderEncodingError.encoderCreationFailed
        }
        encoder.setRenderPipelineState(copyPipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}
