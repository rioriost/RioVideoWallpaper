//
//  FieldLinesRenderer.swift
//  RioVideoWallpaper
//

import Foundation
import MetalKit
import simd

struct FieldLinesVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
    var pointSize: Float
}

final class FieldLinesRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState
    private let fadePipelineState: MTLRenderPipelineState
    private let copyPipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var previousTexture: MTLTexture?
    private var currentTexture: MTLTexture?
    private var textureSize: CGSize = .zero
    private var resetAccumulationOnNextFrame = true

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment"),
              let fullscreenVertexFunction = library.makeFunction(name: "fieldLinesFullscreenVertex"),
              let fadeFragmentFunction = library.makeFunction(name: "fieldLinesFadeFragment"),
              let copyFragmentFunction = library.makeFunction(name: "fieldLinesCopyFragment") else {
            throw RendererError.missingShaderFunction
        }

        let pointDescriptor = MTLRenderPipelineDescriptor()
        pointDescriptor.vertexFunction = vertexFunction
        pointDescriptor.fragmentFunction = fragmentFunction
        pointDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pointDescriptor.colorAttachments[0].isBlendingEnabled = true
        pointDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pointDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pointDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pointDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        let fadeDescriptor = MTLRenderPipelineDescriptor()
        fadeDescriptor.vertexFunction = fullscreenVertexFunction
        fadeDescriptor.fragmentFunction = fadeFragmentFunction
        fadeDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        let copyDescriptor = MTLRenderPipelineDescriptor()
        copyDescriptor.vertexFunction = fullscreenVertexFunction
        copyDescriptor.fragmentFunction = copyFragmentFunction
        copyDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge

        pointPipelineState = try device.makeRenderPipelineState(descriptor: pointDescriptor)
        fadePipelineState = try device.makeRenderPipelineState(descriptor: fadeDescriptor)
        copyPipelineState = try device.makeRenderPipelineState(descriptor: copyDescriptor)
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.samplerCreationFailed
        }
        self.samplerState = samplerState
    }

    func resetAccumulation() {
        resetAccumulationOnNextFrame = true
    }

    func render(
        parameters: FieldLinesParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        let drawableSize = view.drawableSize
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: FieldLinesParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: FieldLinesParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        guard let outputTexture = finalRenderPassDescriptor.colorAttachments[0].texture,
              ensureAccumulationTextures(size: drawableSize, pixelFormat: outputTexture.pixelFormat),
              let currentTexture,
              let previousTexture else {
            renderingError = RenderEncodingError.textureCreationFailed
            return
        }

        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        guard !vertices.isEmpty else { return }
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<FieldLinesVertex>.stride * vertices.count,
            options: [.storageModeShared]
        ) else {
            renderingError = RenderEncodingError.bufferCreationFailed
            return
        }

        let offscreenDescriptor = MTLRenderPassDescriptor()
        offscreenDescriptor.colorAttachments[0].texture = currentTexture
        offscreenDescriptor.colorAttachments[0].loadAction = .clear
        offscreenDescriptor.colorAttachments[0].storeAction = .store
        offscreenDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let offscreenEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenDescriptor) else {
            renderingError = RenderEncodingError.encoderCreationFailed
            return
        }

        if resetAccumulationOnNextFrame {
            resetAccumulationOnNextFrame = false
        } else {
            var fadeFactor = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
            offscreenEncoder.setRenderPipelineState(fadePipelineState)
            offscreenEncoder.setFragmentTexture(previousTexture, index: 0)
            offscreenEncoder.setFragmentSamplerState(samplerState, index: 0)
            offscreenEncoder.setFragmentBytes(&fadeFactor, length: MemoryLayout<Float>.stride, index: 0)
            offscreenEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        offscreenEncoder.setRenderPipelineState(pointPipelineState)
        offscreenEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        offscreenEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count)
        offscreenEncoder.endEncoding()

        guard let drawableEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalRenderPassDescriptor) else {
            renderingError = RenderEncodingError.encoderCreationFailed
            return
        }
        drawableEncoder.setRenderPipelineState(copyPipelineState)
        drawableEncoder.setFragmentTexture(currentTexture, index: 0)
        drawableEncoder.setFragmentSamplerState(samplerState, index: 0)
        drawableEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        drawableEncoder.endEncoding()

        swap(&self.previousTexture, &self.currentTexture)
    }

    private func ensureAccumulationTextures(size: CGSize, pixelFormat: MTLPixelFormat) -> Bool {
        let pixelWidth = max(1, Int(size.width.rounded(.toNearestOrAwayFromZero)))
        let pixelHeight = max(1, Int(size.height.rounded(.toNearestOrAwayFromZero)))
        let roundedSize = CGSize(width: pixelWidth, height: pixelHeight)

        guard previousTexture == nil || currentTexture == nil || textureSize != roundedSize else {
            return true
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        previousTexture = device.makeTexture(descriptor: descriptor)
        currentTexture = device.makeTexture(descriptor: descriptor)
        textureSize = roundedSize
        resetAccumulation()
        return previousTexture != nil && currentTexture != nil
    }

    fileprivate func makeVertices(
        parameters: FieldLinesParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let scale = min(width, height) / 1080.0
        let phase = Float(clock.phase(frameIndex: frameIndex))
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let bandCount = max(1, min(parameters.bandCount, 32))
        let pointsPerBand = max(60, min(parameters.pointsPerBand, 2_400))
        let particleCount = max(0, min(parameters.particleCount, 20_000))
        let speed = Float(max(0.0, parameters.speed))
        let turbulence = Float(max(0.0, parameters.turbulence))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.5))
        let lineAlpha = Float(clamp(parameters.lineAlpha, 0.0, 1.0))
        let particleAlpha = Float(clamp(parameters.particleAlpha, 0.0, 1.0))
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueDrift = Float(parameters.hueDriftDegrees)
        let lineStep = Float(clamp(parameters.lineStep, 0.4, 4.0))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(bandCount * pointsPerBand + particleCount)

        for band in 0..<bandCount {
            let b = Float(band)
            let hue = hueBase + b * 18.0 + hueDrift * sin(phase + b + seedPhase * 0.11)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
            let alpha = lineAlpha * (0.72 + 0.28 * sin(phase + b * 0.5))
            let pointSize = Float(2.2 + Double(band) * 0.18) * Float(parameters.lineWeight) * max(1.0, scale)
            let baseRadius = (260.0 + b * 75.0) * scale
            let amplitude = (120.0 + 60.0 * sin(phase + b)) * scale * max(0.2, turbulence)

            for pointIndex in 0..<pointsPerBand {
                let a = Float(pointIndex) / Float(pointsPerBand) * .pi * 2.0
                let n1 = sin(a * (2.2 + lineStep) + phase * 2.0 + b + seedPhase)
                let n2 = sin(a * (4.8 + lineStep * 1.7) - phase * 3.0 + b * 1.7 + seedPhase * 0.31)
                let n3 = cos(a * (8.5 + lineStep * 1.9) + phase + b * 2.3)
                let radius = baseRadius + amplitude * n1 + 65.0 * scale * turbulence * n2 + 35.0 * scale * n3
                let rotation = 0.22 * max(0.2, speed) * sin(phase + b)
                let screen = SIMD2<Float>(
                    center.x + cos(a + rotation) * radius,
                    center.y + sin(a + rotation) * radius
                )
                vertices.append(
                    FieldLinesVertex(
                        position: normalizedPosition(screen, width: width, height: height),
                        color: SIMD4<Float>(color.x, color.y, color.z, alpha),
                        pointSize: pointSize
                    )
                )
            }
        }

        for particleID in 0..<particleCount {
            let id = Float(particleID)
            let noise = fract(sin(id * 12.9898 + seedPhase) * 43_758.547)
            let angle = Float.pi * 2.0 * fract(id * 0.017)
            let ring = (220.0 + 820.0 * noise) * scale
            let wobble = 80.0 * scale * sin(phase * 2.0 + id * 0.13 + seedPhase * 0.17)
            let radius = ring + wobble
            let screen = SIMD2<Float>(
                center.x + cos(angle * 1.7 + phase + id) * radius,
                center.y + sin(angle * 1.3 - phase + id * 0.7) * radius
            )
            let hue = hueBase - 20.0 + 90.0 * sin(phase + id * 0.01 + seedPhase * 0.07)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation * 0.9, value: brightness)
            vertices.append(
                FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, particleAlpha),
                    pointSize: 2.4 * max(1.0, scale)
                )
            )
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class GenerativeFrameRenderer {
    private let fieldLinesRenderer: FieldLinesRenderer
    private let orbitalRenderer: OrbitalRenderer
    private let softVolumetricRenderer: SoftVolumetricRenderer
    private let gridCityRenderer: GridCityRenderer
    private let interferenceFieldRenderer: InterferenceFieldRenderer
    private let periodicNoiseRenderer: PeriodicNoiseRenderer
    private let cyclicAutomataRenderer: CyclicAutomataRenderer
    private let agentSwarmRenderer: AgentSwarmRenderer
    private let kaleidoscopeRenderer: KaleidoscopeRenderer
    private let voronoiFlowRenderer: VoronoiFlowRenderer
    private let reactionDiffusionRenderer: ReactionDiffusionRenderer
    private let plasmaFieldRenderer: PlasmaFieldRenderer
    private let harmonicTunnelRenderer: HarmonicTunnelRenderer
    private let lissajousWeaveRenderer: LissajousWeaveRenderer
    private let phyllotaxisBloomRenderer: PhyllotaxisBloomRenderer
    private let hexPulseLatticeRenderer: HexPulseLatticeRenderer
    private let superformulaMorphRenderer: SuperformulaMorphRenderer
    private let proceduralPatternRenderer: ProceduralPatternRenderer

    private var diagnostics: [RendererDiagnostics] {
        [fieldLinesRenderer, orbitalRenderer, softVolumetricRenderer, gridCityRenderer,
         interferenceFieldRenderer, periodicNoiseRenderer, cyclicAutomataRenderer,
         agentSwarmRenderer, kaleidoscopeRenderer, voronoiFlowRenderer, reactionDiffusionRenderer,
         plasmaFieldRenderer, harmonicTunnelRenderer, lissajousWeaveRenderer, phyllotaxisBloomRenderer,
         hexPulseLatticeRenderer, superformulaMorphRenderer, proceduralPatternRenderer]
    }

    func checkEncoding() throws {
        if let error = diagnostics.compactMap(\.renderingError).first { throw error }
    }

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        fieldLinesRenderer = try FieldLinesRenderer(device: device, colorPixelFormat: colorPixelFormat)
        orbitalRenderer = try OrbitalRenderer(device: device, colorPixelFormat: colorPixelFormat)
        softVolumetricRenderer = try SoftVolumetricRenderer(device: device, colorPixelFormat: colorPixelFormat)
        gridCityRenderer = try GridCityRenderer(device: device, colorPixelFormat: colorPixelFormat)
        interferenceFieldRenderer = try InterferenceFieldRenderer(device: device, colorPixelFormat: colorPixelFormat)
        periodicNoiseRenderer = try PeriodicNoiseRenderer(device: device, colorPixelFormat: colorPixelFormat)
        cyclicAutomataRenderer = try CyclicAutomataRenderer(device: device, colorPixelFormat: colorPixelFormat)
        agentSwarmRenderer = try AgentSwarmRenderer(device: device, colorPixelFormat: colorPixelFormat)
        kaleidoscopeRenderer = try KaleidoscopeRenderer(device: device, colorPixelFormat: colorPixelFormat)
        voronoiFlowRenderer = try VoronoiFlowRenderer(device: device, colorPixelFormat: colorPixelFormat)
        reactionDiffusionRenderer = try ReactionDiffusionRenderer(device: device, colorPixelFormat: colorPixelFormat)
        plasmaFieldRenderer = try PlasmaFieldRenderer(device: device, colorPixelFormat: colorPixelFormat)
        harmonicTunnelRenderer = try HarmonicTunnelRenderer(device: device, colorPixelFormat: colorPixelFormat)
        lissajousWeaveRenderer = try LissajousWeaveRenderer(device: device, colorPixelFormat: colorPixelFormat)
        phyllotaxisBloomRenderer = try PhyllotaxisBloomRenderer(device: device, colorPixelFormat: colorPixelFormat)
        hexPulseLatticeRenderer = try HexPulseLatticeRenderer(device: device, colorPixelFormat: colorPixelFormat)
        superformulaMorphRenderer = try SuperformulaMorphRenderer(device: device, colorPixelFormat: colorPixelFormat)
        proceduralPatternRenderer = try ProceduralPatternRenderer(device: device, colorPixelFormat: colorPixelFormat)
    }

    func resetAccumulation() {
        fieldLinesRenderer.resetAccumulation()
        orbitalRenderer.resetAccumulation()
        diagnostics.forEach { $0.renderingError = nil }
    }

    func render(
        parameters: RenderParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        diagnostics.forEach { $0.renderingError = nil }
        switch parameters {
        case .fieldLines(let fieldLinesParameters):
            fieldLinesRenderer.render(
                parameters: fieldLinesParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .orbital(let orbitalParameters):
            orbitalRenderer.render(
                parameters: orbitalParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .softVolumetric(let softVolumetricParameters):
            softVolumetricRenderer.render(
                parameters: softVolumetricParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .gridCity(let gridCityParameters):
            gridCityRenderer.render(
                parameters: gridCityParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .interferenceField(let interferenceFieldParameters):
            interferenceFieldRenderer.render(
                parameters: interferenceFieldParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .periodicNoise(let periodicNoiseParameters):
            periodicNoiseRenderer.render(
                parameters: periodicNoiseParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .cyclicAutomata(let cyclicAutomataParameters):
            cyclicAutomataRenderer.render(
                parameters: cyclicAutomataParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .agentSwarm(let agentSwarmParameters):
            agentSwarmRenderer.render(
                parameters: agentSwarmParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .kaleidoscope(let kaleidoscopeParameters):
            kaleidoscopeRenderer.render(
                parameters: kaleidoscopeParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .voronoiFlow(let voronoiFlowParameters):
            voronoiFlowRenderer.render(
                parameters: voronoiFlowParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .reactionDiffusion(let reactionDiffusionParameters):
            reactionDiffusionRenderer.render(
                parameters: reactionDiffusionParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .plasmaField(let plasmaFieldParameters):
            plasmaFieldRenderer.render(
                parameters: plasmaFieldParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .harmonicTunnel(let harmonicTunnelParameters):
            harmonicTunnelRenderer.render(
                parameters: harmonicTunnelParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .lissajousWeave(let lissajousWeaveParameters):
            lissajousWeaveRenderer.render(
                parameters: lissajousWeaveParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .phyllotaxisBloom(let phyllotaxisBloomParameters):
            phyllotaxisBloomRenderer.render(
                parameters: phyllotaxisBloomParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .hexPulseLattice(let hexPulseLatticeParameters):
            hexPulseLatticeRenderer.render(
                parameters: hexPulseLatticeParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .superformulaMorph(let superformulaMorphParameters):
            superformulaMorphRenderer.render(
                parameters: superformulaMorphParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .bloomingCircuits(let proceduralParameters):
            renderProceduralPattern(
                family: .bloomingCircuits,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .cellularBloom(let proceduralParameters):
            renderProceduralPattern(
                family: .cellularBloom,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .chladniPlate(let proceduralParameters):
            renderProceduralPattern(
                family: .chladniPlate,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .circuitTracer(let proceduralParameters):
            renderProceduralPattern(
                family: .circuitTracer,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .closedFlowParticles(let proceduralParameters):
            renderProceduralPattern(
                family: .closedFlowParticles,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .constellationDrift(let proceduralParameters):
            renderProceduralPattern(
                family: .constellationDrift,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .crystalLattice(let proceduralParameters):
            renderProceduralPattern(
                family: .crystalLattice,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .dataMesh(let proceduralParameters):
            renderProceduralPattern(
                family: .dataMesh,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .electricStorm(let proceduralParameters):
            renderProceduralPattern(
                family: .electricStorm,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .sdfTunnel(let proceduralParameters):
            renderProceduralPattern(
                family: .sdfTunnel,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .feedbackSynth(let proceduralParameters):
            renderProceduralPattern(
                family: .feedbackSynth,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .fireworksShow(let proceduralParameters):
            renderProceduralPattern(
                family: .fireworksShow,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .auroraCurtain(let proceduralParameters):
            renderProceduralPattern(
                family: .auroraCurtain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .cityLightsBokeh(let proceduralParameters):
            renderProceduralPattern(
                family: .cityLightsBokeh,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .digitalSand(let proceduralParameters):
            renderProceduralPattern(
                family: .digitalSand,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .inkInWater(let proceduralParameters):
            renderProceduralPattern(
                family: .inkInWater,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .origamiTessellation(let proceduralParameters):
            renderProceduralPattern(
                family: .origamiTessellation,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .sakuraDrift(let proceduralParameters):
            renderProceduralPattern(
                family: .sakuraDrift,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .snowfallDepth(let proceduralParameters):
            renderProceduralPattern(
                family: .snowfallDepth,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .solarCorona(let proceduralParameters):
            renderProceduralPattern(
                family: .solarCorona,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .underwaterCaustics(let proceduralParameters):
            renderProceduralPattern(
                family: .underwaterCaustics,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .volumetricNebula(let proceduralParameters):
            renderProceduralPattern(
                family: .volumetricNebula,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .fluidNodes(let proceduralParameters):
            renderProceduralPattern(
                family: .fluidNodes,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .fourierKnots(let proceduralParameters):
            renderProceduralPattern(
                family: .fourierKnots,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .guillocheRose(let proceduralParameters):
            renderProceduralPattern(
                family: .guillocheRose,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .growingNetwork(let proceduralParameters):
            renderProceduralPattern(
                family: .growingNetwork,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .instancedGeometry(let proceduralParameters):
            renderProceduralPattern(
                family: .instancedGeometry,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .laserRibbons(let proceduralParameters):
            renderProceduralPattern(
                family: .laserRibbons,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .luminousBubbles(let proceduralParameters):
            renderProceduralPattern(
                family: .luminousBubbles,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .metaballField(let proceduralParameters):
            renderProceduralPattern(
                family: .metaballField,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .moireRings(let proceduralParameters):
            renderProceduralPattern(
                family: .moireRings,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .neonVortex(let proceduralParameters):
            renderProceduralPattern(
                family: .neonVortex,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .particleFountain(let proceduralParameters):
            renderProceduralPattern(
                family: .particleFountain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .rainCurtain(let proceduralParameters):
            renderProceduralPattern(
                family: .rainCurtain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .penroseTiling(let proceduralParameters):
            renderProceduralPattern(
                family: .penroseTiling,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .pulseNetwork(let proceduralParameters):
            renderProceduralPattern(
                family: .pulseNetwork,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .radialOscilloscope(let proceduralParameters):
            renderProceduralPattern(
                family: .radialOscilloscope,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .ribbonCascade(let proceduralParameters):
            renderProceduralPattern(
                family: .ribbonCascade,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .scanlineTopography(let proceduralParameters):
            renderProceduralPattern(
                family: .scanlineTopography,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .schoolingSwarm(let proceduralParameters):
            renderProceduralPattern(
                family: .schoolingSwarm,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .truchetFlow(let proceduralParameters):
            renderProceduralPattern(
                family: .truchetFlow,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .waveTerrain(let proceduralParameters):
            renderProceduralPattern(
                family: .waveTerrain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .wireframeMorph(let proceduralParameters):
            renderProceduralPattern(
                family: .wireframeMorph,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        case .proceduralPattern(let family, let proceduralParameters):
            renderProceduralPattern(
                family: family,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                in: view,
                commandBuffer: commandBuffer,
                renderPassDescriptor: renderPassDescriptor
            )
        }
    }

    func render(
        parameters: RenderParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        diagnostics.forEach { $0.renderingError = nil }
        switch parameters {
        case .fieldLines(let fieldLinesParameters):
            fieldLinesRenderer.render(
                parameters: fieldLinesParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .orbital(let orbitalParameters):
            orbitalRenderer.render(
                parameters: orbitalParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .softVolumetric(let softVolumetricParameters):
            softVolumetricRenderer.render(
                parameters: softVolumetricParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .gridCity(let gridCityParameters):
            gridCityRenderer.render(
                parameters: gridCityParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .interferenceField(let interferenceFieldParameters):
            interferenceFieldRenderer.render(
                parameters: interferenceFieldParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .periodicNoise(let periodicNoiseParameters):
            periodicNoiseRenderer.render(
                parameters: periodicNoiseParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .cyclicAutomata(let cyclicAutomataParameters):
            cyclicAutomataRenderer.render(
                parameters: cyclicAutomataParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .agentSwarm(let agentSwarmParameters):
            agentSwarmRenderer.render(
                parameters: agentSwarmParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .kaleidoscope(let kaleidoscopeParameters):
            kaleidoscopeRenderer.render(
                parameters: kaleidoscopeParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .voronoiFlow(let voronoiFlowParameters):
            voronoiFlowRenderer.render(
                parameters: voronoiFlowParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .reactionDiffusion(let reactionDiffusionParameters):
            reactionDiffusionRenderer.render(
                parameters: reactionDiffusionParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .plasmaField(let plasmaFieldParameters):
            plasmaFieldRenderer.render(
                parameters: plasmaFieldParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .harmonicTunnel(let harmonicTunnelParameters):
            harmonicTunnelRenderer.render(
                parameters: harmonicTunnelParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .lissajousWeave(let lissajousWeaveParameters):
            lissajousWeaveRenderer.render(
                parameters: lissajousWeaveParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .phyllotaxisBloom(let phyllotaxisBloomParameters):
            phyllotaxisBloomRenderer.render(
                parameters: phyllotaxisBloomParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .hexPulseLattice(let hexPulseLatticeParameters):
            hexPulseLatticeRenderer.render(
                parameters: hexPulseLatticeParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .superformulaMorph(let superformulaMorphParameters):
            superformulaMorphRenderer.render(
                parameters: superformulaMorphParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .bloomingCircuits(let proceduralParameters):
            renderProceduralPattern(
                family: .bloomingCircuits,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .cellularBloom(let proceduralParameters):
            renderProceduralPattern(
                family: .cellularBloom,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .chladniPlate(let proceduralParameters):
            renderProceduralPattern(
                family: .chladniPlate,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .circuitTracer(let proceduralParameters):
            renderProceduralPattern(
                family: .circuitTracer,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .closedFlowParticles(let proceduralParameters):
            renderProceduralPattern(
                family: .closedFlowParticles,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .constellationDrift(let proceduralParameters):
            renderProceduralPattern(
                family: .constellationDrift,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .crystalLattice(let proceduralParameters):
            renderProceduralPattern(
                family: .crystalLattice,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .dataMesh(let proceduralParameters):
            renderProceduralPattern(
                family: .dataMesh,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .electricStorm(let proceduralParameters):
            renderProceduralPattern(
                family: .electricStorm,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .sdfTunnel(let proceduralParameters):
            renderProceduralPattern(
                family: .sdfTunnel,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .feedbackSynth(let proceduralParameters):
            renderProceduralPattern(
                family: .feedbackSynth,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .fireworksShow(let proceduralParameters):
            renderProceduralPattern(
                family: .fireworksShow,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .auroraCurtain(let proceduralParameters):
            renderProceduralPattern(
                family: .auroraCurtain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .cityLightsBokeh(let proceduralParameters):
            renderProceduralPattern(
                family: .cityLightsBokeh,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .digitalSand(let proceduralParameters):
            renderProceduralPattern(
                family: .digitalSand,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .inkInWater(let proceduralParameters):
            renderProceduralPattern(
                family: .inkInWater,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .origamiTessellation(let proceduralParameters):
            renderProceduralPattern(
                family: .origamiTessellation,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .sakuraDrift(let proceduralParameters):
            renderProceduralPattern(
                family: .sakuraDrift,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .snowfallDepth(let proceduralParameters):
            renderProceduralPattern(
                family: .snowfallDepth,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .solarCorona(let proceduralParameters):
            renderProceduralPattern(
                family: .solarCorona,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .underwaterCaustics(let proceduralParameters):
            renderProceduralPattern(
                family: .underwaterCaustics,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .volumetricNebula(let proceduralParameters):
            renderProceduralPattern(
                family: .volumetricNebula,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .fluidNodes(let proceduralParameters):
            renderProceduralPattern(
                family: .fluidNodes,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .fourierKnots(let proceduralParameters):
            renderProceduralPattern(
                family: .fourierKnots,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .guillocheRose(let proceduralParameters):
            renderProceduralPattern(
                family: .guillocheRose,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .growingNetwork(let proceduralParameters):
            renderProceduralPattern(
                family: .growingNetwork,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .instancedGeometry(let proceduralParameters):
            renderProceduralPattern(
                family: .instancedGeometry,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .laserRibbons(let proceduralParameters):
            renderProceduralPattern(
                family: .laserRibbons,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .luminousBubbles(let proceduralParameters):
            renderProceduralPattern(
                family: .luminousBubbles,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .metaballField(let proceduralParameters):
            renderProceduralPattern(
                family: .metaballField,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .moireRings(let proceduralParameters):
            renderProceduralPattern(
                family: .moireRings,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .neonVortex(let proceduralParameters):
            renderProceduralPattern(
                family: .neonVortex,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .particleFountain(let proceduralParameters):
            renderProceduralPattern(
                family: .particleFountain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .rainCurtain(let proceduralParameters):
            renderProceduralPattern(
                family: .rainCurtain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .penroseTiling(let proceduralParameters):
            renderProceduralPattern(
                family: .penroseTiling,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .pulseNetwork(let proceduralParameters):
            renderProceduralPattern(
                family: .pulseNetwork,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .radialOscilloscope(let proceduralParameters):
            renderProceduralPattern(
                family: .radialOscilloscope,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .ribbonCascade(let proceduralParameters):
            renderProceduralPattern(
                family: .ribbonCascade,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .scanlineTopography(let proceduralParameters):
            renderProceduralPattern(
                family: .scanlineTopography,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .schoolingSwarm(let proceduralParameters):
            renderProceduralPattern(
                family: .schoolingSwarm,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .truchetFlow(let proceduralParameters):
            renderProceduralPattern(
                family: .truchetFlow,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .waveTerrain(let proceduralParameters):
            renderProceduralPattern(
                family: .waveTerrain,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .wireframeMorph(let proceduralParameters):
            renderProceduralPattern(
                family: .wireframeMorph,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        case .proceduralPattern(let family, let proceduralParameters):
            renderProceduralPattern(
                family: family,
                parameters: proceduralParameters,
                seed: seed,
                frameIndex: frameIndex,
                clock: clock,
                drawableSize: drawableSize,
                outputTexture: outputTexture,
                commandBuffer: commandBuffer
            )
        }
    }

    private func renderProceduralPattern(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        proceduralPatternRenderer.render(
            family: family,
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            in: view,
            commandBuffer: commandBuffer,
            renderPassDescriptor: renderPassDescriptor
        )
    }

    private func renderProceduralPattern(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        proceduralPatternRenderer.render(
            family: family,
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            outputTexture: outputTexture,
            commandBuffer: commandBuffer
        )
    }
}

final class OrbitalRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState
    private let fadePipelineState: MTLRenderPipelineState
    private let copyPipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var previousTexture: MTLTexture?
    private var currentTexture: MTLTexture?
    private var textureSize: CGSize = .zero
    private var resetAccumulationOnNextFrame = true

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment"),
              let fullscreenVertexFunction = library.makeFunction(name: "fieldLinesFullscreenVertex"),
              let fadeFragmentFunction = library.makeFunction(name: "fieldLinesFadeFragment"),
              let copyFragmentFunction = library.makeFunction(name: "fieldLinesCopyFragment") else {
            throw RendererError.missingShaderFunction
        }

        let pointDescriptor = MTLRenderPipelineDescriptor()
        pointDescriptor.vertexFunction = vertexFunction
        pointDescriptor.fragmentFunction = fragmentFunction
        pointDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pointDescriptor.colorAttachments[0].isBlendingEnabled = true
        pointDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pointDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pointDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pointDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        let fadeDescriptor = MTLRenderPipelineDescriptor()
        fadeDescriptor.vertexFunction = fullscreenVertexFunction
        fadeDescriptor.fragmentFunction = fadeFragmentFunction
        fadeDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        let copyDescriptor = MTLRenderPipelineDescriptor()
        copyDescriptor.vertexFunction = fullscreenVertexFunction
        copyDescriptor.fragmentFunction = copyFragmentFunction
        copyDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge

        pointPipelineState = try device.makeRenderPipelineState(descriptor: pointDescriptor)
        fadePipelineState = try device.makeRenderPipelineState(descriptor: fadeDescriptor)
        copyPipelineState = try device.makeRenderPipelineState(descriptor: copyDescriptor)
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.samplerCreationFailed
        }
        self.samplerState = samplerState
    }

    func resetAccumulation() {
        resetAccumulationOnNextFrame = true
    }

    func render(
        parameters: OrbitalParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: OrbitalParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: OrbitalParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        guard let outputTexture = finalRenderPassDescriptor.colorAttachments[0].texture,
              ensureAccumulationTextures(size: drawableSize, pixelFormat: outputTexture.pixelFormat),
              let currentTexture,
              let previousTexture else {
            renderingError = RenderEncodingError.textureCreationFailed
            return
        }

        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        guard !vertices.isEmpty else { return }
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<FieldLinesVertex>.stride * vertices.count,
            options: [.storageModeShared]
        ) else {
            renderingError = RenderEncodingError.bufferCreationFailed
            return
        }

        let offscreenDescriptor = MTLRenderPassDescriptor()
        offscreenDescriptor.colorAttachments[0].texture = currentTexture
        offscreenDescriptor.colorAttachments[0].loadAction = .clear
        offscreenDescriptor.colorAttachments[0].storeAction = .store
        offscreenDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let offscreenEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenDescriptor) else {
            renderingError = RenderEncodingError.encoderCreationFailed
            return
        }

        if resetAccumulationOnNextFrame {
            resetAccumulationOnNextFrame = false
        } else {
            var fadeFactor = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
            offscreenEncoder.setRenderPipelineState(fadePipelineState)
            offscreenEncoder.setFragmentTexture(previousTexture, index: 0)
            offscreenEncoder.setFragmentSamplerState(samplerState, index: 0)
            offscreenEncoder.setFragmentBytes(&fadeFactor, length: MemoryLayout<Float>.stride, index: 0)
            offscreenEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        offscreenEncoder.setRenderPipelineState(pointPipelineState)
        offscreenEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        offscreenEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count)
        offscreenEncoder.endEncoding()

        guard let drawableEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalRenderPassDescriptor) else {
            renderingError = RenderEncodingError.encoderCreationFailed
            return
        }
        drawableEncoder.setRenderPipelineState(copyPipelineState)
        drawableEncoder.setFragmentTexture(currentTexture, index: 0)
        drawableEncoder.setFragmentSamplerState(samplerState, index: 0)
        drawableEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        drawableEncoder.endEncoding()

        swap(&self.previousTexture, &self.currentTexture)
    }

    private func ensureAccumulationTextures(size: CGSize, pixelFormat: MTLPixelFormat) -> Bool {
        let pixelWidth = max(1, Int(size.width.rounded(.toNearestOrAwayFromZero)))
        let pixelHeight = max(1, Int(size.height.rounded(.toNearestOrAwayFromZero)))
        let roundedSize = CGSize(width: pixelWidth, height: pixelHeight)

        guard previousTexture == nil || currentTexture == nil || textureSize != roundedSize else {
            return true
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private

        previousTexture = device.makeTexture(descriptor: descriptor)
        currentTexture = device.makeTexture(descriptor: descriptor)
        textureSize = roundedSize
        resetAccumulation()
        return previousTexture != nil && currentTexture != nil
    }

    fileprivate func makeVertices(
        parameters: OrbitalParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let scale = min(width, height) / 1080.0
        let phase = Float(clock.phase(frameIndex: frameIndex))
        let loopTime = Float(clock.normalizedLoopTime(frameIndex: frameIndex))
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let orbitCount = max(1, min(parameters.orbitCount, 24))
        let pointsPerOrbit = max(120, min(parameters.pointsPerOrbit, 2_000))
        let satelliteCount = max(0, min(parameters.satelliteCount, 360))
        let speed = Float(max(0.0, parameters.speed))
        let cycleCount = Float(max(1, min(5, Int((parameters.speed * 2.0).rounded()))))
        let radiusScale = Float(clamp(parameters.radiusScale, 0.3, 1.8))
        let eccentricity = Float(clamp(parameters.eccentricity, 0.0, 0.9))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.5))
        let orbitAlpha = Float(clamp(parameters.orbitAlpha, 0.0, 1.0))
        let satelliteAlpha = Float(clamp(parameters.satelliteAlpha, 0.0, 1.0))
        let glowSize = Float(clamp(parameters.glowSize, 0.4, 6.0))
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(orbitCount * pointsPerOrbit + satelliteCount * 3)

        for orbit in 0..<orbitCount {
            let index = Float(orbit)
            let progress = Float(orbit + 1) / Float(orbitCount + 1)
            let baseRadius = (145.0 + progress * 780.0) * scale * radiusScale
            let ellipseX = baseRadius * (1.0 + eccentricity * 0.55)
            let ellipseY = baseRadius * (1.0 - eccentricity * 0.42)
            let tilt = seedPhase * 0.18 + index * 0.52 + phase * cycleCount
            let wobble = 0.055 + eccentricity * 0.06
            let hue = hueBase + hueSpread * sin(index * 0.73 + seedPhase)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
            let alpha = orbitAlpha * (0.58 + 0.42 * progress)
            let pointSize = (1.4 + glowSize * 0.42 + progress * 0.6) * max(1.0, scale)

            for pointIndex in 0..<pointsPerOrbit {
                let a = Float(pointIndex) / Float(pointsPerOrbit) * .pi * 2.0
                let precess = phase * cycleCount
                let radialPulse = 1.0 + wobble * sin(a * 3.0 + phase * cycleCount + index + seedPhase)
                let local = SIMD2<Float>(
                    cos(a + precess) * ellipseX * radialPulse,
                    sin(a - precess) * ellipseY * radialPulse
                )
                let screen = rotate(local, by: tilt) + center
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha),
                    pointSize: pointSize
                ))
            }
        }

        for satellite in 0..<satelliteCount {
            let id = Float(satellite)
            let orbit = Float(satellite % orbitCount)
            let progress = (orbit + 1.0) / Float(orbitCount + 1)
            let baseRadius = (145.0 + progress * 780.0) * scale * radiusScale
            let ellipseX = baseRadius * (1.0 + eccentricity * 0.55)
            let ellipseY = baseRadius * (1.0 - eccentricity * 0.42)
            let tilt = seedPhase * 0.18 + orbit * 0.52 + phase * cycleCount
            let direction: Float = satellite % 2 == 0 ? 1.0 : -1.0
            let a = .pi * 2.0 * fract(id * 0.173 + loopTime * cycleCount * direction)
            let local = SIMD2<Float>(
                cos(a) * ellipseX,
                sin(a) * ellipseY
            )
            let screen = rotate(local, by: tilt) + center
            let hue = hueBase + hueSpread * cos(id * 0.31 + phase + seedPhase)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
            let pointSize = (2.6 + glowSize * 1.1 + progress * 2.0) * max(1.0, scale)
            vertices.append(FieldLinesVertex(
                position: normalizedPosition(screen, width: width, height: height),
                color: SIMD4<Float>(color.x, color.y, color.z, satelliteAlpha),
                pointSize: pointSize
            ))

            let trailColor = SIMD4<Float>(color.x, color.y, color.z, satelliteAlpha * 0.38)
            for trailStep in 1...2 {
                let trailAngle = a - direction * Float(trailStep) * 0.035 * (1.0 + speed)
                let trailLocal = SIMD2<Float>(
                    cos(trailAngle) * ellipseX,
                    sin(trailAngle) * ellipseY
                )
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(rotate(trailLocal, by: tilt) + center, width: width, height: height),
                    color: trailColor,
                    pointSize: pointSize * (1.0 - Float(trailStep) * 0.22)
                ))
            }
        }

        return vertices
    }

    private func rotate(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD2<Float>(
            point.x * c - point.y * s,
            point.x * s + point.y * c
        )
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class SoftVolumetricRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let pointDescriptor = MTLRenderPipelineDescriptor()
        pointDescriptor.vertexFunction = vertexFunction
        pointDescriptor.fragmentFunction = fragmentFunction
        pointDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pointDescriptor.colorAttachments[0].isBlendingEnabled = true
        pointDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pointDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pointDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pointDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: pointDescriptor)
    }

    func render(
        parameters: SoftVolumetricParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: SoftVolumetricParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: SoftVolumetricParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: SoftVolumetricParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let scale = min(width, height) / 1080.0
        let phase = Float(clock.phase(frameIndex: frameIndex))
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let cloudCount = max(1, min(parameters.cloudCount, 24))
        let pointsPerCloud = max(80, min(parameters.pointsPerCloud, 1_800))
        let layerCount = max(1, min(parameters.layerCount, 10))
        let cycleCount = Float(max(1, min(5, Int((parameters.speed * 2.0).rounded()))))
        let turbulence = Float(max(0.0, parameters.turbulence))
        let spread = Float(clamp(parameters.spread, 0.3, 2.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.3))
        let cloudAlpha = Float(clamp(parameters.cloudAlpha, 0.0, 1.0))
        let coreAlpha = Float(clamp(parameters.coreAlpha, 0.0, 1.0))
        let glowSize = Float(clamp(parameters.glowSize, 0.5, 10.0))
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(cloudCount * pointsPerCloud + cloudCount * layerCount)

        for cloud in 0..<cloudCount {
            let c = Float(cloud)
            let cloudSeed = seedPhase + c * 1.731
            let baseAngle = .pi * 2.0 * fract(c * 0.271 + Float(seed % 97) * 0.003)
            let distance = (90.0 + 420.0 * fract(c * 0.619 + seedPhase * 0.17)) * scale * spread
            let drift = phase * cycleCount
            let anchor = center + SIMD2<Float>(
                cos(baseAngle + drift) * distance,
                sin(baseAngle * 0.7 - drift) * distance * 0.72
            )
            let cloudRadius = (120.0 + 280.0 * fract(c * 0.413 + seedPhase * 0.23)) * scale * spread
            let hue = hueBase + hueSpread * sin(c * 0.63 + seedPhase)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)

            for layer in 0..<layerCount {
                let l = Float(layer)
                let layerProgress = Float(layer + 1) / Float(layerCount + 1)
                let layerAngle = cloudSeed + l * 0.81 + phase * cycleCount
                let local = SIMD2<Float>(
                    cos(layerAngle) * cloudRadius * 0.28 * layerProgress,
                    sin((cloudSeed + l * 0.81) * 1.3 + phase * cycleCount) * cloudRadius * 0.18 * layerProgress
                )
                let screen = anchor + local
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, coreAlpha * alphaBoost * (1.0 - layerProgress * 0.25)),
                    pointSize: (cloudRadius * 0.18 + glowSize * 10.0 * scale) * (1.0 + layerProgress * 0.45)
                ))
            }

            for point in 0..<pointsPerCloud {
                let p = Float(point)
                let r = sqrt(fract(sin((p + c * 97.0) * 12.9898 + cloudSeed) * 43_758.547))
                let a = .pi * 2.0 * fract(p * 0.3819 + cloudSeed * 0.11)
                let swirl = phase * cycleCount + sin(phase + p * 0.031) * turbulence * 0.16
                let ellipse = SIMD2<Float>(
                    cos(a + swirl) * cloudRadius * r,
                    sin(a * 1.17 - swirl) * cloudRadius * r * (0.52 + turbulence * 0.22)
                )
                let wave = SIMD2<Float>(
                    sin(phase * cycleCount + p * 0.07 + cloudSeed),
                    cos(phase * cycleCount + p * 0.053 + cloudSeed * 0.7)
                ) * cloudRadius * 0.06 * turbulence
                let screen = anchor + ellipse + wave
                let particleHue = hue + hueSpread * 0.28 * sin(p * 0.021 + phase + cloudSeed)
                let particleColor = hsvToRGB(hueDegrees: particleHue, saturation: saturation, value: brightness)
                let edgeFalloff = 1.0 - r * 0.72
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(
                        particleColor.x,
                        particleColor.y,
                        particleColor.z,
                        cloudAlpha * alphaBoost * edgeFalloff
                    ),
                    pointSize: (glowSize * (1.0 + edgeFalloff * 0.9) + 2.0) * max(1.0, scale)
                ))
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class GridCityRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let pointDescriptor = MTLRenderPipelineDescriptor()
        pointDescriptor.vertexFunction = vertexFunction
        pointDescriptor.fragmentFunction = fragmentFunction
        pointDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pointDescriptor.colorAttachments[0].isBlendingEnabled = true
        pointDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pointDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pointDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pointDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pointDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: pointDescriptor)
    }

    func render(
        parameters: GridCityParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: GridCityParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: GridCityParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: GridCityParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let centerX = width * 0.5
        let horizonY = height * (0.36 - Float(clamp(parameters.perspective, 0.25, 1.0)) * 0.08)
        let groundY = height * 0.92
        let scale = min(width, height) / 1080.0
        let phase = Float(clock.phase(frameIndex: frameIndex))
        let loopTime = Float(clock.normalizedLoopTime(frameIndex: frameIndex))
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let laneCount = max(2, min(parameters.laneCount, 36))
        let pointsPerLane = max(40, min(parameters.pointsPerLane, 1_200))
        let towerCount = max(0, min(parameters.towerCount, 240))
        let perspective = Float(clamp(parameters.perspective, 0.25, 1.0))
        let depth = Float(clamp(parameters.depth, 0.2, 1.0))
        let cycleCount = Float(max(1, min(5, Int((parameters.speed * 2.0).rounded()))))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.3))
        let gridAlpha = Float(clamp(parameters.gridAlpha, 0.0, 1.0))
        let towerAlpha = Float(clamp(parameters.towerAlpha, 0.0, 1.0))
        let glowSize = Float(clamp(parameters.glowSize, 0.4, 8.0))
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(laneCount * pointsPerLane + pointsPerLane * 10 + towerCount * 16)

        let gridColor = hsvToRGB(hueDegrees: hueBase, saturation: saturation, value: brightness)
        let roadHalfWidth = width * (0.24 + depth * 0.22)
        let laneTotal = laneCount * 2 + 1
        for lane in 0..<laneTotal {
            let normalizedLane = Float(lane - laneCount) / Float(max(1, laneCount))
            let groundX = centerX + normalizedLane * roadHalfWidth
            for point in 0..<pointsPerLane {
                let z = Float(point) / Float(max(1, pointsPerLane - 1))
                let curvedZ = pow(z, 1.65 + perspective * 0.85)
                let y = horizonY + (groundY - horizonY) * curvedZ
                let x = centerX + (groundX - centerX) * curvedZ
                let pulse = 0.64 + 0.36 * sin(phase * cycleCount + normalizedLane * 2.0 + z * 14.0)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(SIMD2<Float>(x, y), width: width, height: height),
                    color: SIMD4<Float>(gridColor.x, gridColor.y, gridColor.z, gridAlpha * alphaBoost * pulse),
                    pointSize: (1.1 + glowSize * 0.26 + curvedZ * 1.8) * max(1.0, scale)
                ))
            }
        }

        let crossLineCount = max(6, laneCount)
        for cross in 0..<crossLineCount {
            let moving = fract(Float(cross) / Float(crossLineCount) + loopTime * cycleCount)
            let curvedZ = pow(moving, 1.65 + perspective * 0.85)
            let y = horizonY + (groundY - horizonY) * curvedZ
            let halfWidth = roadHalfWidth * curvedZ
            let pointCount = max(80, pointsPerLane / 2)
            for point in 0..<pointCount {
                let t = Float(point) / Float(max(1, pointCount - 1))
                let x = centerX - halfWidth + halfWidth * 2.0 * t
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(SIMD2<Float>(x, y), width: width, height: height),
                    color: SIMD4<Float>(gridColor.x, gridColor.y, gridColor.z, gridAlpha * alphaBoost * (0.55 + curvedZ * 0.45) * LoopMath.lifetimeEnvelope(moving)),
                    pointSize: (1.0 + glowSize * 0.2 + curvedZ * 1.6) * max(1.0, scale)
                ))
            }
        }

        for tower in 0..<towerCount {
            let t = Float(tower)
            let side: Float = tower % 2 == 0 ? -1.0 : 1.0
            let row = fract(t * 0.3183 + seedPhase * 0.07)
            let curvedZ = pow(row, 1.55 + perspective * 0.75)
            let yBase = horizonY + (groundY - horizonY) * curvedZ
            let sideOffset = roadHalfWidth * curvedZ + (36.0 + 360.0 * fract(t * 0.217 + seedPhase)) * scale * curvedZ
            let x = centerX + side * sideOffset
            let towerHeight = (80.0 + 360.0 * fract(t * 0.713 + seedPhase * 0.13)) * scale * (0.35 + curvedZ)
            let towerHue = hueBase + hueSpread * sin(t * 0.41 + seedPhase)
            let color = hsvToRGB(hueDegrees: towerHue, saturation: saturation, value: brightness)
            let verticalPoints = 8
            for point in 0..<verticalPoints {
                let p = Float(point) / Float(verticalPoints - 1)
                let y = yBase - towerHeight * p
                let flicker = 0.72 + 0.28 * sin(phase * cycleCount + t * 0.73 + p * 8.0)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(SIMD2<Float>(x, y), width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, towerAlpha * alphaBoost * flicker),
                    pointSize: (2.0 + glowSize * 0.55 + curvedZ * 2.2) * max(1.0, scale)
                ))
            }

            for window in 0..<8 {
                let wx = x + side * Float(window % 2 == 0 ? -1 : 1) * (6.0 + curvedZ * 16.0) * scale
                let wy = yBase - towerHeight * (0.12 + Float(window) * 0.095)
                let windowHue = towerHue + 18.0 * sin(Float(window) + seedPhase)
                let windowColor = hsvToRGB(hueDegrees: windowHue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(SIMD2<Float>(wx, wy), width: width, height: height),
                    color: SIMD4<Float>(windowColor.x, windowColor.y, windowColor.z, towerAlpha * alphaBoost * 0.78),
                    pointSize: (2.4 + glowSize * 0.42 + curvedZ * 1.8) * max(1.0, scale)
                ))
            }
        }

        let streamCount = max(6, laneCount / 2)
        for stream in 0..<streamCount {
            let lane = Float(stream - streamCount / 2) / Float(max(1, streamCount))
            let groundX = centerX + lane * roadHalfWidth * 0.72
            let movingZ = fract(Float(stream) * 0.137 + loopTime * cycleCount)
            let hue = hueBase + hueSpread * cos(Float(stream) * 0.59 + seedPhase)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
            for trail in 0..<18 {
                let z = fract(movingZ - Float(trail) * 0.012)
                let curvedZ = pow(z, 1.65 + perspective * 0.85)
                let y = horizonY + (groundY - horizonY) * curvedZ
                let x = centerX + (groundX - centerX) * curvedZ
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(SIMD2<Float>(x, y), width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, towerAlpha * alphaBoost * (1.0 - Float(trail) / 22.0) * LoopMath.lifetimeEnvelope(z)),
                    pointSize: (2.8 + glowSize * 0.95 + curvedZ * 3.0) * max(1.0, scale)
                ))
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class InterferenceFieldRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: InterferenceFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: InterferenceFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: InterferenceFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }

        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: InterferenceFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let samples = max(24, min(parameters.samplesPerAxis, 180))
        let waveCount = max(3, min(parameters.waveCount, 18))
        let cycleCount = max(1, min(4, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount) +
            Float(parameters.phaseOffset / 180.0 * Double.pi)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let frequency = Float(max(0.1, parameters.spatialFrequency)) * .pi * 2.0
        let symmetry = Float(clamp(parameters.symmetry, 0.0, 1.0))
        let contrast = Float(clamp(parameters.contrast, 0.01, 0.98))
        let threshold = 0.24 + contrast * 0.20
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.5))
        let pointAlpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let aspect = width / max(1.0, height)
        let step = 2.0 / Float(max(1, samples - 1))

        var directions: [SIMD2<Float>] = []
        directions.reserveCapacity(waveCount)
        for wave in 0..<waveCount {
            let regularAngle = Float(wave) / Float(waveCount) * .pi * 2.0
            let jitter = (fract(sin(Float(wave) * 19.19 + seedPhase) * 43758.547) - 0.5) * (1.0 - symmetry) * 1.2
            let angle = regularAngle + jitter + seedPhase * 0.03
            directions.append(SIMD2<Float>(cos(angle), sin(angle)))
        }

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(samples * samples / 2)

        for yIndex in 0..<samples {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<samples {
                let x = -1.0 + Float(xIndex) * step
                let p = SIMD2<Float>(x * aspect, y)
                let radius = length(p)
                let edgeDistance = min(1.0 - abs(x), 1.0 - abs(y))
                let edgeFade = max(0.0, min(1.0, edgeDistance / 0.10))
                guard edgeFade > 0.01 else { continue }

                var field: Float = 0.0
                var fieldGradient = SIMD2<Float>(repeating: 0)
                for wave in 0..<waveCount {
                    let direction = directions[wave]
                    let harmonic = 1.0 + Float(wave % 3) * 0.18
                    let wavePhase = phase * Float(1 + wave % 3) + Float(wave) * 0.61 + seedPhase * 0.11
                    let value = dot(p, direction) * frequency * harmonic + wavePhase
                    field += cos(value)
                    fieldGradient += direction * sin(value) * harmonic
                }

                let normalized = field / Float(waveCount)
                let ridge = pow(max(0.0, abs(normalized) - threshold) / max(0.001, 1.0 - threshold), 0.55 + contrast)
                let lattice = pow(max(0.0, 1.0 - length(fieldGradient) / Float(waveCount) * 0.72), 1.6)
                let banding = pow(abs(sin((normalized + 1.0) * .pi * Float(waveCount) * 0.55)), 1.25)
                let pulse = 0.78 + 0.22 * sin(phase + radius * .pi * 3.0 + normalized * .pi)
                let intensity = max(max(ridge, lattice * 0.50), banding * 0.36) * edgeFade * pulse
                guard intensity > 0.025 else { continue }

                let swirl = SIMD2<Float>(
                    -p.y * sin(phase + radius * 2.0),
                    p.x * cos(phase - radius * 1.7)
                ) * 0.014
                let drift = fieldGradient * (0.018 + symmetry * 0.028) * intensity + swirl * intensity
                let screen = SIMD2<Float>(
                    (x + drift.x) * width * 0.5 + width * 0.5,
                    (y + drift.y) * height * 0.5 + height * 0.5
                )
                let hue = hueBase + hueSpread * (0.5 + normalized * 0.5) + 24.0 * sin(phase + radius * 2.4)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, pointAlpha * min(1.0, intensity * 1.35)),
                    pointSize: pointSize * (0.85 + intensity * 2.4)
                ))
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class PeriodicNoiseRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: PeriodicNoiseParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: PeriodicNoiseParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: PeriodicNoiseParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }

        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: PeriodicNoiseParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let samples = max(24, min(parameters.samplesPerAxis, 180))
        let octaveCount = max(1, min(parameters.octaveCount, 8))
        let cycleCount = max(1, min(4, Int((parameters.speed * 2.0).rounded())))
        let loopPhase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let timeCircle = SIMD2<Float>(cos(loopPhase), sin(loopPhase))
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let noiseScale = Float(max(0.1, parameters.noiseScale))
        let warpAmount = Float(clamp(parameters.warpAmount, 0.0, 2.0))
        let turbulence = Float(max(0.0, parameters.turbulence))
        let contourSharpness = Float(clamp(parameters.contourSharpness, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let pointAlpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let aspect = width / max(1.0, height)
        let step = 2.0 / Float(max(1, samples - 1))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(samples * samples / 2)

        for yIndex in 0..<samples {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<samples {
                let x = -1.0 + Float(xIndex) * step
                let p = SIMD2<Float>(x * aspect, y)
                let radius = length(p)
                let edgeDistance = min(1.0 - abs(x), 1.0 - abs(y))
                let edgeFade = max(0.0, min(1.0, edgeDistance / 0.10))
                guard edgeFade > 0.01 else { continue }

                let warp = periodicNoise(
                    p * (noiseScale * 0.7) + SIMD2<Float>(seedPhase * 0.03, -seedPhase * 0.02),
                    timeCircle: timeCircle,
                    seedPhase: seedPhase + 1.7,
                    octaveCount: max(1, octaveCount - 1),
                    turbulence: turbulence
                )
                let domain = p * noiseScale + SIMD2<Float>(
                    sin(warp * .pi + timeCircle.x * 1.6 + timeCircle.y * 0.7),
                    cos(warp * .pi * 0.9 - timeCircle.y * 1.4 + timeCircle.x * 0.8)
                ) * warpAmount
                let value = periodicNoise(
                    domain,
                    timeCircle: timeCircle,
                    seedPhase: seedPhase,
                    octaveCount: octaveCount,
                    turbulence: turbulence
                )

                let normalized = (value + 1.0) * 0.5
                let contour = abs(sin((normalized * (4.0 + contourSharpness * 10.0) + seedPhase * 0.03) * .pi))
                let softField = pow(max(0.0, normalized), 0.52)
                let contourField = pow(max(0.0, contour), 1.45 - contourSharpness * 0.95)
                let veinField = pow(abs(sin((value + warp * 0.45) * .pi * 5.0 + timeCircle.x * 1.2)), 2.0)
                let intensity = max(mix(softField, contourField, contourSharpness), veinField * 0.42) * edgeFade
                guard intensity > 0.03 else { continue }

                let drift = SIMD2<Float>(
                    sin(value * .pi + loopPhase) * 0.018,
                    cos(value * .pi * 0.82 - loopPhase) * 0.018
                ) * (0.8 + warpAmount * 1.45) * intensity
                let screen = SIMD2<Float>(
                    (x + drift.x) * width * 0.5 + width * 0.5,
                    (y + drift.y) * height * 0.5 + height * 0.5
                )
                let hue = hueBase + hueSpread * normalized + 22.0 * sin(loopPhase + radius * 2.8)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, pointAlpha * alphaBoost * min(1.0, intensity * 1.45)),
                    pointSize: pointSize * (0.86 + intensity * 2.45)
                ))
            }
        }

        return vertices
    }

    private func periodicNoise(
        _ point: SIMD2<Float>,
        timeCircle: SIMD2<Float>,
        seedPhase: Float,
        octaveCount: Int,
        turbulence: Float
    ) -> Float {
        var value: Float = 0
        var amplitude: Float = 0.58
        var amplitudeTotal: Float = 0
        var frequency: Float = 1.0

        for octave in 0..<octaveCount {
            let o = Float(octave)
            let angle = seedPhase * 0.19 + o * 1.173
            let direction = SIMD2<Float>(cos(angle), sin(angle))
            let crossDirection = SIMD2<Float>(-direction.y, direction.x)
            let phaseA = dot(point, direction) * frequency * .pi * 2.0 +
                timeCircle.x * (1.2 + o * 0.17) +
                timeCircle.y * (0.7 + o * 0.11) +
                seedPhase
            let phaseB = dot(point, crossDirection) * frequency * .pi * 2.0 -
                timeCircle.y * (1.0 + o * 0.13) +
                timeCircle.x * (0.8 + o * 0.09) +
                seedPhase * 0.63
            let octaveValue = sin(phaseA) * cos(phaseB)
            value += octaveValue * amplitude
            amplitudeTotal += amplitude
            frequency *= 1.85 + turbulence * 0.18
            amplitude *= 0.54
        }

        return amplitudeTotal > 0 ? value / amplitudeTotal : 0
    }

    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a * (1.0 - t) + b * t
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class CyclicAutomataRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: CyclicAutomataParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: CyclicAutomataParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: CyclicAutomataParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: CyclicAutomataParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let aspect = width / max(1.0, height)
        let cells = max(24, min(parameters.cellsPerAxis, 180))
        let stateCount = max(3, min(parameters.stateCount, 14))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount) +
            Float(parameters.phaseOffset / 180.0 * Double.pi)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let cellScale = Float(max(0.2, parameters.cellScale))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.cellAlpha, 0.0, 1.0))
        let cellSize = Float(parameters.cellSize) * max(1.0, scale)
        let neighborhood = Float(clamp(parameters.neighborhood, 0.0, 1.0))
        let mutation = Float(clamp(parameters.mutation, 0.0, 1.0))
        let edgeSharpness = Float(clamp(parameters.edgeSharpness, 0.0, 1.0))
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let step = 2.0 / Float(max(1, cells - 1))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(cells * cells)

        for yIndex in 0..<cells {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<cells {
                let x = -1.0 + Float(xIndex) * step
                let p = SIMD2<Float>(x * aspect, y)
                let lattice = SIMD2<Float>(Float(xIndex), Float(yIndex))
                let base = cyclicField(
                    point: p * cellScale,
                    lattice: lattice,
                    phase: phase,
                    seedPhase: seedPhase,
                    neighborhood: neighborhood,
                    mutation: mutation
                )
                let neighborA = cyclicField(
                    point: (p + SIMD2<Float>(step * aspect, 0)) * cellScale,
                    lattice: lattice + SIMD2<Float>(1, 0),
                    phase: phase,
                    seedPhase: seedPhase,
                    neighborhood: neighborhood,
                    mutation: mutation
                )
                let neighborB = cyclicField(
                    point: (p + SIMD2<Float>(0, step)) * cellScale,
                    lattice: lattice + SIMD2<Float>(0, 1),
                    phase: phase,
                    seedPhase: seedPhase,
                    neighborhood: neighborhood,
                    mutation: mutation
                )

                let stateProgress = LoopMath.cyclicPaletteProgress(fract(base), states: stateCount)
                let edge = min(1.0, abs(base - neighborA) * 3.0 + abs(base - neighborB) * 3.0)
                let reactionFront = pow(abs(sin(base * Float(stateCount) * .pi + phase)), 1.15)
                let intensity = mix(0.32 + reactionFront * 0.42, edge, edgeSharpness)
                guard intensity > 0.04 else { continue }

                let jitter = SIMD2<Float>(
                    sin(base * .pi * 2.0 + phase) * 0.006,
                    cos(base * .pi * 2.0 - phase) * 0.006
                ) * mutation
                let screen = SIMD2<Float>(
                    (x + jitter.x) * width * 0.5 + width * 0.5,
                    (y + jitter.y) * height * 0.5 + height * 0.5
                )
                let hue = hueBase + hueSpread * stateProgress + 18.0 * sin(phase + base * .pi)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * min(1.0, intensity * 1.45)),
                    pointSize: cellSize * (0.72 + intensity * 1.35)
                ))
            }
        }

        return vertices
    }

    private func cyclicField(
        point: SIMD2<Float>,
        lattice: SIMD2<Float>,
        phase: Float,
        seedPhase: Float,
        neighborhood: Float,
        mutation: Float
    ) -> Float {
        let waveA = sin(point.x * .pi * 2.0 + phase + seedPhase * 0.31)
        let waveB = cos(point.y * .pi * 2.0 - phase + seedPhase * 0.47)
        let waveC = sin((point.x + point.y) * .pi * (1.15 + neighborhood) + phase * 2.0)
        let cellular = sin((lattice.x * 0.37 + lattice.y * 0.61 + seedPhase) * (1.0 + mutation * 0.7))
        let value = waveA * 0.30 + waveB * 0.26 + waveC * (0.22 + neighborhood * 0.16) + cellular * mutation * 0.22
        return fract(value * 0.5 + 0.5)
    }

    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a * (1.0 - t) + b * t
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class AgentSwarmRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: AgentSwarmParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: AgentSwarmParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: AgentSwarmParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: AgentSwarmParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let agentCount = max(1, min(parameters.agentCount, 1_200))
        let trailCount = max(0, min(parameters.trailCount, 16))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let orbitRadius = Float(clamp(parameters.orbitRadius, 0.05, 1.4))
        let cohesion = Float(clamp(parameters.cohesion, 0.0, 1.0))
        let wander = Float(clamp(parameters.wander, 0.0, 1.0))
        let separation = Float(clamp(parameters.separation, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let agentAlpha = Float(clamp(parameters.agentAlpha, 0.0, 1.0))
        let trailAlpha = Float(clamp(parameters.trailAlpha, 0.0, 1.0))
        let agentSize = Float(parameters.agentSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(agentCount * (trailCount + 1))

        for agent in 0..<agentCount {
            let id = Float(agent)
            let group = Float(agent % 7)
            let groupAngle = group / 7.0 * .pi * 2.0 + seedPhase * 0.13
            let groupAnchor = SIMD2<Float>(
                cos(groupAngle + phase),
                sin(groupAngle - phase)
            ) * cohesion * 0.44
            let base = fract(id * 0.618_034 + seedPhase * 0.017)
            let localSeed = seedPhase + id * 0.137
            let trailSteps = trailCount + 1

            for trail in 0..<trailSteps {
                let trailProgress = Float(trail) / Float(max(1, trailSteps))
                let localPhase = phase - trailProgress * 0.42 * Float(cycleCount)
                let pathA = localPhase + localSeed + Float(agent % 5) * 0.12
                let pathB = localPhase - localSeed * 0.71 + Float(agent % 7) * 0.09
                let wandering = SIMD2<Float>(
                    sin(pathA) + sin(pathB + id * 0.11) * wander,
                    cos(pathB) + cos(pathA - id * 0.09) * wander
                ) * orbitRadius * 0.42
                let lane = SIMD2<Float>(
                    fract(base + sin(id) * 0.03) * 2.0 - 1.0 + sin(localPhase) * 0.35,
                    fract(base * 1.7 + cos(id * 0.7) * 0.04) * 2.0 - 1.0 - sin(localPhase) * 0.35
                ) * separation
                let position = wrap(groupAnchor + wandering + lane * 0.52)
                let screen = SIMD2<Float>(
                    (position.x * 0.5 + 0.5) * width,
                    (position.y * 0.5 + 0.5) * height
                )
                let intensity = 1.0 - trailProgress * 0.78
                let hue = hueBase + hueSpread * fract(base + group * 0.071) + 22.0 * sin(localPhase + id * 0.03)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                let alpha = (trail == 0 ? agentAlpha : trailAlpha) * alphaBoost * intensity
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha),
                    pointSize: agentSize * (trail == 0 ? 1.0 : 0.72 + intensity * 0.26)
                ))
            }
        }

        return vertices
    }

    private func wrap(_ point: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2<Float>(
            fract((point.x + 1.0) * 0.5) * 2.0 - 1.0,
            fract((point.y + 1.0) * 0.5) * 2.0 - 1.0
        )
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class KaleidoscopeRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: KaleidoscopeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: KaleidoscopeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: KaleidoscopeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: KaleidoscopeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let rings = max(1, min(parameters.ringCount, 24))
        let segments = max(3, min(parameters.segments, 32))
        let pointsPerRing = max(60, min(parameters.pointsPerRing, 1_200))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let radiusScale = Float(clamp(parameters.radiusScale, 0.1, 1.4))
        let twist = Float(clamp(parameters.twist, 0.0, 1.0))
        let petalAmount = Float(clamp(parameters.petalAmount, 0.0, 1.0))
        let complexity = Float(clamp(parameters.complexity, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let wedgeAngle = (.pi * 2.0) / Float(segments)

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(rings * pointsPerRing * 2)

        for ring in 0..<rings {
            let ringProgress = Float(ring + 1) / Float(rings)
            let baseRadius = pow(ringProgress, 0.72) * radiusScale
            let ringPhase = seedPhase + Float(ring) * 0.47
            let ringHue = hueBase + hueSpread * ringProgress

            for index in 0..<pointsPerRing {
                let sample = Float(index) / Float(pointsPerRing)
                let mirroredSample = sample < 0.5 ? sample * 2.0 : (1.0 - sample) * 2.0
                let localAngle = mirroredSample * wedgeAngle
                let fold = Float(index % 2 == 0 ? 1.0 : -1.0)
                let segment = (index * segments) / pointsPerRing
                let segmentAngle = Float(segment % segments) * wedgeAngle
                let harmonicA = sin(sample * .pi * 2.0 * Float(segments) + phase + ringPhase)
                let harmonicB = cos(sample * .pi * 2.0 * Float(segments / 2 + 2) - phase + ringPhase)
                let petal = 1.0 + petalAmount * 0.22 *
                    sin(localAngle * Float(segments) + phase + ringProgress * .pi)
                let lace = 1.0 + complexity * 0.14 * harmonicA + complexity * 0.10 * harmonicB
                let radius = baseRadius * petal * lace
                let angle = segmentAngle + localAngle * fold + twist * ringProgress * sin(phase) +
                    sin(ringPhase + phase) * twist * 0.08
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                let screen = SIMD2<Float>(
                    x * width * 0.46 + width * 0.5,
                    y * height * 0.46 + height * 0.5
                )
                let edgeFade = min(1.0, max(0.0, 1.18 - radius * 0.28))
                let sparkle = 0.64 + 0.36 * abs(sin(phase + sample * .pi * 2.0 + ringPhase))
                let hue = ringHue + 34.0 * harmonicA + 18.0 * harmonicB
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)

                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * edgeFade * sparkle),
                    pointSize: pointSize * (0.74 + ringProgress * 0.56 + abs(harmonicA) * 0.34)
                ))

                if complexity > 0.35 {
                    let counterAngle = segmentAngle - localAngle * fold - twist * ringProgress * sin(phase)
                    let counterRadius = radius * (0.70 + complexity * 0.22)
                    let counterScreen = SIMD2<Float>(
                        cos(counterAngle) * counterRadius * width * 0.46 + width * 0.5,
                        sin(counterAngle) * counterRadius * height * 0.46 + height * 0.5
                    )
                    vertices.append(FieldLinesVertex(
                        position: normalizedPosition(counterScreen, width: width, height: height),
                        color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * edgeFade * 0.56),
                        pointSize: pointSize * 0.72
                    ))
                }
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class VoronoiFlowRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: VoronoiFlowParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: VoronoiFlowParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: VoronoiFlowParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: VoronoiFlowParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let aspect = width / max(1.0, height)
        let scale = min(width, height) / 1080.0
        let siteCount = max(4, min(parameters.siteCount, 96))
        let samples = max(32, min(parameters.samplesPerAxis, 180))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let cellScale = Float(clamp(parameters.cellScale, 0.2, 3.0))
        let edgeWidth = Float(clamp(parameters.edgeWidth, 0.02, 1.0))
        let pulseAmount = Float(clamp(parameters.pulseAmount, 0.0, 1.0))
        let drift = Float(clamp(parameters.drift, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let edgeAlpha = Float(clamp(parameters.edgeAlpha, 0.0, 1.0))
        let fillAlpha = Float(clamp(parameters.fillAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let step = 2.0 / Float(max(1, samples - 1))
        let threshold = 0.010 + edgeWidth * 0.070
        let sites = makeSites(
            count: siteCount,
            seedPhase: seedPhase,
            phase: phase,
            drift: drift
        )

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(samples * samples)

        for yIndex in 0..<samples {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<samples {
                let x = -1.0 + Float(xIndex) * step
                let p = SIMD2<Float>(x * aspect * cellScale, y * cellScale)
                var nearestDistance = Float.greatestFiniteMagnitude
                var secondDistance = Float.greatestFiniteMagnitude
                var nearestIndex = 0

                for siteIndex in 0..<sites.count {
                    let site = SIMD2<Float>(sites[siteIndex].x * aspect * cellScale, sites[siteIndex].y * cellScale)
                    let distance = simd_length_squared(p - site)
                    if distance < nearestDistance {
                        secondDistance = nearestDistance
                        nearestDistance = distance
                        nearestIndex = siteIndex
                    } else if distance < secondDistance {
                        secondDistance = distance
                    }
                }

                let gap = sqrt(max(0.0, secondDistance)) - sqrt(max(0.0, nearestDistance))
                let edge = 1.0 - smoothstep(0.0, threshold, gap)
                let cellPulse = 0.5 + 0.5 * sin(
                    phase + Float(nearestIndex) * 0.73 + sqrt(nearestDistance) * 9.0
                )
                let fill = fillAlpha * (0.42 + cellPulse * pulseAmount * 0.58)
                let intensity = max(edge * edgeAlpha, fill)
                guard intensity > 0.01 else { continue }

                let screen = SIMD2<Float>(
                    (x * 0.5 + 0.5) * width,
                    (y * 0.5 + 0.5) * height
                )
                let siteProgress = Float(nearestIndex) / Float(max(1, siteCount - 1))
                let hue = hueBase + hueSpread * siteProgress + 20.0 * cellPulse + 12.0 * sin(phase)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, intensity * alphaBoost),
                    pointSize: pointSize * (0.82 + edge * 0.78 + cellPulse * pulseAmount * 0.24)
                ))
            }
        }

        return vertices
    }

    private func makeSites(
        count: Int,
        seedPhase: Float,
        phase: Float,
        drift: Float
    ) -> [SIMD2<Float>] {
        var sites: [SIMD2<Float>] = []
        sites.reserveCapacity(count)

        for index in 0..<count {
            let id = Float(index)
            let baseX = fract(0.137 + id * 0.618_034 + seedPhase * 0.011) * 2.0 - 1.0
            let baseY = fract(0.431 + id * 0.414_214 + seedPhase * 0.017) * 2.0 - 1.0
            let local = seedPhase + id * 0.379
            let offset = SIMD2<Float>(
                sin(phase + local + Float(index % 5) * 0.08),
                cos(phase - local * 0.83 + Float(index % 7) * 0.07)
            ) * drift * 0.26
            sites.append(wrap(SIMD2<Float>(baseX, baseY) + offset))
        }

        return sites
    }

    private func wrap(_ point: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2<Float>(
            fract((point.x + 1.0) * 0.5) * 2.0 - 1.0,
            fract((point.y + 1.0) * 0.5) * 2.0 - 1.0
        )
    }

    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / max(0.0001, edge1 - edge0), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class ReactionDiffusionRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: ReactionDiffusionParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: ReactionDiffusionParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: ReactionDiffusionParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: ReactionDiffusionParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let aspect = width / max(1.0, height)
        let scale = min(width, height) / 1080.0
        let samples = max(32, min(parameters.samplesPerAxis, 180))
        let layerCount = max(1, min(parameters.layerCount, 10))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let patternScale = Float(clamp(parameters.patternScale, 0.2, 3.5))
        let stripeSharpness = Float(clamp(parameters.stripeSharpness, 0.0, 1.0))
        let diffusion = Float(clamp(parameters.diffusion, 0.0, 1.0))
        let turbulence = Float(clamp(parameters.turbulence, 0.0, 2.2))
        let symmetry = Float(clamp(parameters.symmetry, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let step = 2.0 / Float(max(1, samples - 1))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(samples * samples)

        for yIndex in 0..<samples {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<samples {
                let x = -1.0 + Float(xIndex) * step
                let point = SIMD2<Float>(x * aspect, y)
                let value = reactionField(
                    point: point * patternScale,
                    phase: phase,
                    seedPhase: seedPhase,
                    layerCount: layerCount,
                    diffusion: diffusion,
                    turbulence: turbulence,
                    symmetry: symmetry
                )
                let stripe = pow(abs(sin(value * .pi)), 0.72 + stripeSharpness * 2.1)
                let spot = pow(max(0.0, cos(value * .pi * 1.7)), 1.2 + diffusion * 2.4)
                let front = max(stripe * (1.0 - diffusion * 0.42), spot * diffusion)
                guard front > 0.035 else { continue }

                let screen = SIMD2<Float>(
                    (x * 0.5 + 0.5) * width,
                    (y * 0.5 + 0.5) * height
                )
                let hue = hueBase + hueSpread * fract(value * 0.17 + front * 0.23) + 18.0 * sin(phase)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * min(1.0, front * 1.25)),
                    pointSize: pointSize * (0.72 + front * 1.25)
                ))
            }
        }

        return vertices
    }

    private func reactionField(
        point: SIMD2<Float>,
        phase: Float,
        seedPhase: Float,
        layerCount: Int,
        diffusion: Float,
        turbulence: Float,
        symmetry: Float
    ) -> Float {
        var value: Float = 0
        var weight: Float = 0
        let radius = simd_length(point)
        let angle = atan2(point.y, point.x)

        for layer in 0..<layerCount {
            let fLayer = Float(layer + 1)
            let localPhase = phase + seedPhase * (0.17 + fLayer * 0.03) + fLayer * 0.09
            let direction = seedPhase + fLayer * 1.256
            let basis = point.x * cos(direction) + point.y * sin(direction)
            let cross = point.x * sin(direction * 0.73) - point.y * cos(direction * 0.91)
            let radial = sin(radius * (.pi * (1.2 + fLayer * 0.28)) - localPhase)
            let stripe = sin(basis * .pi * (1.6 + fLayer * 0.42) + localPhase)
            let cells = cos((basis + cross) * .pi * (0.9 + fLayer * 0.33) - localPhase)
            let symmetric = sin(angle * (3.0 + symmetry * 9.0) + localPhase) * symmetry
            let layerValue = stripe * (0.42 + turbulence * 0.08) +
                cells * (0.22 + diffusion * 0.25) +
                radial * (0.18 + turbulence * 0.10) +
                symmetric * 0.18
            let layerWeight = 1.0 / fLayer
            value += layerValue * layerWeight
            weight += layerWeight
        }

        return value / max(0.001, weight)
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class PlasmaFieldRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: PlasmaFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: PlasmaFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: PlasmaFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: PlasmaFieldParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let aspect = width / max(1.0, height)
        let scale = min(width, height) / 1080.0
        let samples = max(32, min(parameters.samplesPerAxis, 190))
        let octaves = max(1, min(parameters.octaveCount, 9))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let waveScale = Float(clamp(parameters.waveScale, 0.2, 3.5))
        let warpAmount = Float(clamp(parameters.warpAmount, 0.0, 1.6))
        let contrast = Float(clamp(parameters.contrast, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let hueBase = Float(parameters.hueBaseDegrees)
        let hueSpread = Float(parameters.hueSpreadDegrees)
        let flowAngle = Float(parameters.flowAngle / 180.0 * Double.pi)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let step = 2.0 / Float(max(1, samples - 1))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(samples * samples)

        for yIndex in 0..<samples {
            let y = -1.0 + Float(yIndex) * step
            for xIndex in 0..<samples {
                let x = -1.0 + Float(xIndex) * step
                let point = SIMD2<Float>(x * aspect, y)
                let value = plasmaValue(
                    point: point * waveScale,
                    phase: phase,
                    seedPhase: seedPhase,
                    flowAngle: flowAngle,
                    octaves: octaves,
                    warpAmount: warpAmount
                )
                let shaped = mix(value, smoothstep(0.18, 0.92, value), contrast)
                let pulse = 0.82 + 0.18 * sin(phase + value * .pi * 2.0)
                let screen = SIMD2<Float>(
                    (x * 0.5 + 0.5) * width,
                    (y * 0.5 + 0.5) * height
                )
                let hue = hueBase + hueSpread * shaped + 24.0 * sin(phase + shaped * .pi)
                let colorValue = brightness * (0.68 + shaped * 0.48)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: colorValue)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * (0.74 + pulse * 0.30)),
                    pointSize: pointSize * (1.04 + shaped * 0.82)
                ))
            }
        }

        return vertices
    }

    private func plasmaValue(
        point: SIMD2<Float>,
        phase: Float,
        seedPhase: Float,
        flowAngle: Float,
        octaves: Int,
        warpAmount: Float
    ) -> Float {
        var p = point
        let flow = SIMD2<Float>(cos(flowAngle), sin(flowAngle))
        p += flow * sin(phase + seedPhase) * warpAmount * 0.22
        var value: Float = 0
        var weight: Float = 0

        for octave in 0..<octaves {
            let fOctave = Float(octave + 1)
            let localPhase = phase + seedPhase * (0.19 + fOctave * 0.03) + fOctave * 0.11
            let direction = flowAngle + seedPhase * 0.21 + fOctave * 1.137
            let axis = p.x * cos(direction) + p.y * sin(direction)
            let cross = p.x * sin(direction * 0.77) - p.y * cos(direction * 0.91)
            let warp = SIMD2<Float>(
                sin(cross * .pi * (0.7 + fOctave * 0.17) + localPhase),
                cos(axis * .pi * (0.8 + fOctave * 0.19) - localPhase)
            ) * warpAmount * 0.16 / fOctave
            let q = p + warp
            let waveA = sin((q.x + q.y) * .pi * (0.9 + fOctave * 0.28) + localPhase)
            let waveB = cos(simd_length(q) * .pi * (1.2 + fOctave * 0.22) - localPhase)
            let waveC = sin((q.x - q.y) * .pi * (0.6 + fOctave * 0.33) - localPhase)
            let octaveWeight = 1.0 / fOctave
            value += (waveA * 0.42 + waveB * 0.36 + waveC * 0.22) * octaveWeight
            weight += octaveWeight
        }

        return fract(value / max(0.001, weight) * 0.5 + 0.5)
    }

    private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / max(0.0001, edge1 - edge0), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a * (1.0 - t) + b * t
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class HarmonicTunnelRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: HarmonicTunnelParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: HarmonicTunnelParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: HarmonicTunnelParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: HarmonicTunnelParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let rings = max(6, min(parameters.ringCount, 80))
        let points = max(36, min(parameters.pointsPerRing, 440))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let depth = Float(clamp(parameters.tunnelDepth, 0.0, 1.0))
        let waveAmplitude = Float(clamp(parameters.waveAmplitude, 0.0, 0.9))
        let twist = Float(clamp(parameters.twist, 0.0, 1.0))
        let spokeAmount = Float(clamp(parameters.spokeAmount, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let perspective = Float(clamp(parameters.perspective, 0.0, 1.0))
        let centerDrift = Float(clamp(parameters.centerDrift, 0.0, 0.75))
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let minSide = min(width, height)
        let maxRadius = minSide * 0.82
        let center = SIMD2<Float>(
            width * (0.5 + centerDrift * 0.18 * sin(phase + seedPhase)),
            height * (0.5 + centerDrift * 0.18 * cos(phase - seedPhase))
        )

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(rings * points)

        for ringIndex in 0..<rings {
            let ringT = Float(ringIndex) / Float(max(1, rings - 1))
            let travel = fract(ringT + phase / (.pi * 2.0))
            let depthEase = pow(max(0.001, travel), 0.55 + perspective * 0.85)
            let radius = maxRadius * (0.12 + depthEase * (1.18 + depth * 0.46))
            let ringAlpha = alpha * alphaBoost * (0.26 + travel * 0.86) * LoopMath.lifetimeEnvelope(travel)
            let ringPhase = phase + ringT * .pi * 2.0

            for pointIndex in 0..<points {
                let pointT = Float(pointIndex) / Float(points)
                let angle = pointT * .pi * 2.0 +
                    twist * (1.0 - travel) * .pi * 2.4 +
                    seedPhase * 0.17
                let wave = sin(angle * (3.0 + spokeAmount * 10.0) + ringPhase) *
                    cos(angle * 2.0 - ringPhase + seedPhase)
                let spoke = 0.5 + 0.5 * cos(angle * (6.0 + spokeAmount * 18.0) - phase)
                let rippleRadius = radius * (1.0 + waveAmplitude * 0.24 * wave + spokeAmount * 0.045 * spoke)
                let direction = SIMD2<Float>(cos(angle), sin(angle))
                let screen = center + SIMD2<Float>(
                    direction.x * rippleRadius,
                    direction.y * rippleRadius * 0.78
                )

                guard screen.x > -width * 0.12,
                      screen.x < width * 1.12,
                      screen.y > -height * 0.12,
                      screen.y < height * 1.12 else {
                    continue
                }

                let hue = Float(parameters.hueBaseDegrees) +
                    Float(parameters.hueSpreadDegrees) * travel +
                    20.0 * sin(angle + phase)
                let value = brightness * (0.54 + 0.30 * travel + 0.22 * spoke)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: value)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, ringAlpha),
                    pointSize: pointSize * (0.62 + travel * 0.72 + spoke * 0.28)
                ))
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class LissajousWeaveRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: LissajousWeaveParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: LissajousWeaveParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: LissajousWeaveParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: LissajousWeaveParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let curves = max(1, min(parameters.curveCount, 26))
        let points = max(80, min(parameters.pointsPerCurve, 1400))
        let frequencyX = Float(max(1, min(parameters.frequencyX, 14)))
        let frequencyY = Float(max(1, min(parameters.frequencyY, 14)))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let phaseSpread = Float(clamp(parameters.phaseSpread, 0.0, 1.0))
        let weaveAmount = Float(clamp(parameters.weaveAmount, 0.0, 1.0))
        let modulation = Float(clamp(parameters.modulation, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let rotation = Float(parameters.rotation / 180.0 * Double.pi)
        let cosRotation = cos(rotation)
        let sinRotation = sin(rotation)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let radius = SIMD2<Float>(width * 0.43, height * 0.42)

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(curves * points)

        for curveIndex in 0..<curves {
            let curveT = curves == 1 ? 0.0 : Float(curveIndex) / Float(curves - 1)
            let curvePhase = seedPhase * 0.19 +
                curveT * phaseSpread * .pi * 2.0 +
                phase + curveT * 0.09
            let curveAlpha = alpha * alphaBoost * (0.72 + 0.28 * sin(curvePhase + phase))

            for pointIndex in 0..<points {
                let pointT = Float(pointIndex) / Float(points)
                let theta = pointT * .pi * 2.0
                let braid = sin(theta * (frequencyX + frequencyY) + phase + curvePhase)
                let modulatedTheta = theta + braid * weaveAmount * 0.22
                var x = sin(frequencyX * modulatedTheta + curvePhase)
                var y = sin(frequencyY * modulatedTheta + phase * 2.0 + (curvePhase - phase) * 1.37)
                x += weaveAmount * 0.22 * sin((frequencyY + 1.0) * theta - phase + seedPhase)
                y += weaveAmount * 0.22 * cos((frequencyX + 1.0) * theta + phase - seedPhase)
                let envelope = 0.78 + modulation * 0.20 * sin(theta * 2.0 + phase + curveT * .pi)
                let rotated = SIMD2<Float>(
                    x * cosRotation - y * sinRotation,
                    x * sinRotation + y * cosRotation
                ) * envelope
                let screen = center + SIMD2<Float>(
                    rotated.x * radius.x,
                    rotated.y * radius.y
                )

                let hue = Float(parameters.hueBaseDegrees) +
                    Float(parameters.hueSpreadDegrees) * pointT +
                    32.0 * curveT +
                    16.0 * sin(phase + braid)
                let value = brightness * (0.60 + 0.26 * abs(braid) + 0.18 * curveT)
                let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: value)
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, curveAlpha),
                    pointSize: pointSize * (0.72 + 0.45 * abs(braid))
                ))
            }
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class PhyllotaxisBloomRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: PhyllotaxisBloomParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: PhyllotaxisBloomParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: PhyllotaxisBloomParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: PhyllotaxisBloomParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let pointCount = max(200, min(parameters.pointCount, 14_000))
        let armCount = Float(max(1, min(parameters.armCount, 16)))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let spiralTightness = Float(clamp(parameters.spiralTightness, 0.0, 1.0))
        let bloomAmount = Float(clamp(parameters.bloomAmount, 0.0, 1.0))
        let pulseAmount = Float(clamp(parameters.pulseAmount, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let rotation = Float(parameters.rotation / 180.0 * Double.pi) + phase
        let centerDrift = Float(clamp(parameters.centerDrift, 0.0, 0.75))
        let center = SIMD2<Float>(
            width * (0.5 + centerDrift * 0.16 * sin(phase + seedPhase)),
            height * (0.5 + centerDrift * 0.16 * cos(phase - seedPhase))
        )
        let maxRadius = min(width, height) * (0.18 + spiralTightness * 0.34 + bloomAmount * 0.16)
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(pointCount)

        for index in 0..<pointCount {
            let i = Float(index)
            let t = i / Float(max(1, pointCount - 1))
            let armWave = sin(t * armCount * .pi * 2.0 + phase + seedPhase)
            let bloom = 1.0 + bloomAmount * 0.26 * sin(phase + t * .pi * 2.0)
            let radius = sqrt(t) * maxRadius * bloom * (0.82 + 0.18 * spiralTightness)
            let angle = i * goldenAngle + rotation + armWave * bloomAmount * 0.18
            let petal = 1.0 + 0.10 * bloomAmount * sin(angle * armCount - phase)
            let screen = center + SIMD2<Float>(
                cos(angle) * radius * petal,
                sin(angle) * radius * petal
            )
            let pulse = 0.72 + pulseAmount * 0.28 * (0.5 + 0.5 * sin(phase + t * .pi * 8.0))
            let hue = Float(parameters.hueBaseDegrees) +
                Float(parameters.hueSpreadDegrees) * t +
                24.0 * armWave
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness * pulse)
            vertices.append(FieldLinesVertex(
                position: normalizedPosition(screen, width: width, height: height),
                color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * pulse),
                pointSize: pointSize * (0.62 + pulse * 0.54 + (1.0 - t) * 0.20)
            ))
        }

        return vertices
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class HexPulseLatticeRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: HexPulseLatticeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: HexPulseLatticeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: HexPulseLatticeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: HexPulseLatticeParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let scale = min(width, height) / 1080.0
        let columns = max(4, min(parameters.columnCount, 56))
        let rows = max(4, min(parameters.rowCount, 42))
        let pointsPerEdge = max(2, min(parameters.pointsPerEdge, 18))
        let sqrt3 = Float(sqrt(3.0))
        let horizontalSpan = Float(columns) * 1.5 + 0.5
        let verticalSpan = (Float(rows) + 0.75) * sqrt3
        let coverSpan = hypot(width, height) * 1.10
        let radius = max(coverSpan / horizontalSpan, coverSpan / verticalSpan)
        let gridWidth = horizontalSpan * radius
        let gridHeight = verticalSpan * radius
        let origin = SIMD2<Float>((width - gridWidth) * 0.5, (height - gridHeight) * 0.5)
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let pulseAmount = Float(clamp(parameters.pulseAmount, 0.0, 1.0))
        let waveScale = Float(clamp(parameters.waveScale, 0.0, 1.0))
        let lineThickness = Float(clamp(parameters.lineThickness, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let basePointSize = Float(parameters.pointSize) * max(1.0, scale)
        let geometryRotation = Float(parameters.rotation / 180.0 * Double.pi)

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(columns * rows * 6 * pointsPerEdge)

        for column in 0..<columns {
            for row in 0..<rows {
                let centerX = origin.x + (Float(column) * 1.5 + 0.75) * radius
                let centerY = origin.y + (Float(row) + 0.5 + (column.isMultiple(of: 2) ? 0.0 : 0.5)) * sqrt3 * radius
                let cellCenter = SIMD2<Float>(centerX, centerY)
                let cellPhase = phase +
                    Float(column) * (0.34 + waveScale * 0.54) +
                    Float(row) * (0.29 + waveScale * 0.47) +
                    seedPhase * 0.31
                let cellPulse = 0.5 + 0.5 * sin(cellPhase)
                let edgeGlow = 0.58 + pulseAmount * 0.42 * cellPulse

                for edge in 0..<6 {
                    let startAngle = Float.pi / 6.0 + Float(edge) * Float.pi / 3.0
                    let endAngle = Float.pi / 6.0 + Float(edge + 1) * Float.pi / 3.0
                    let start = cellCenter + SIMD2<Float>(cos(startAngle) * radius, sin(startAngle) * radius)
                    let end = cellCenter + SIMD2<Float>(cos(endAngle) * radius, sin(endAngle) * radius)

                    for sample in 0..<pointsPerEdge {
                        let t = Float(sample) / Float(max(1, pointsPerEdge - 1))
                        let edgeWave = sin(cellPhase + t * .pi * 2.0 + Float(edge) * 0.71)
                        let localPulse = 0.68 + pulseAmount * 0.32 * (0.5 + 0.5 * edgeWave)
                        let screen = rotate(mix(start, end, t) - center, by: geometryRotation) + center
                        let hue = Float(parameters.hueBaseDegrees) +
                            Float(parameters.hueSpreadDegrees) * (0.5 + 0.5 * edgeWave) +
                            Float(edge) * 6.0
                        let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness * localPulse)
                        vertices.append(FieldLinesVertex(
                            position: normalizedPosition(screen, width: width, height: height),
                            color: SIMD4<Float>(color.x, color.y, color.z, alpha * alphaBoost * edgeGlow),
                            pointSize: basePointSize * (0.72 + lineThickness * 0.68 + localPulse * 0.34)
                        ))
                    }
                }
            }
        }

        return vertices
    }

    private func mix(_ lhs: SIMD2<Float>, _ rhs: SIMD2<Float>, _ amount: Float) -> SIMD2<Float> {
        lhs + (rhs - lhs) * amount
    }

    private func rotate(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD2<Float>(
            point.x * c - point.y * s,
            point.x * s + point.y * c
        )
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class SuperformulaMorphRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        parameters: SuperformulaMorphParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        parameters: SuperformulaMorphParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        parameters: SuperformulaMorphParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        parameters: SuperformulaMorphParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let scale = min(width, height) / 1080.0
        let contourCount = max(2, min(parameters.contourCount, 28))
        let pointsPerContour = max(120, min(parameters.pointsPerContour, 1_600))
        let harmonicA = Float(max(2, min(parameters.harmonicA, 24)))
        let harmonicB = Float(max(2, min(parameters.harmonicB, 24)))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let morphAmount = Float(clamp(parameters.morphAmount, 0.0, 1.0))
        let radialScale = Float(clamp(parameters.radialScale, 0.20, 1.35))
        let contourSpread = Float(clamp(parameters.contourSpread, 0.0, 1.0))
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0))
        let alphaBoost = Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let basePointSize = Float(parameters.pointSize) * max(1.0, scale)
        let rotation = Float(parameters.rotation / 180.0 * Double.pi) + phase
        let centerDrift = Float(clamp(parameters.centerDrift, 0.0, 0.75))
        let center = SIMD2<Float>(
            width * (0.5 + centerDrift * 0.14 * sin(phase + seedPhase)),
            height * (0.5 + centerDrift * 0.14 * cos(phase - seedPhase))
        )
        let maxRadius = min(width, height) * 0.48 * radialScale

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(contourCount * pointsPerContour)

        for contour in 0..<contourCount {
            let layer = Float(contour) / Float(max(1, contourCount - 1))
            let layerScale = 0.18 + (0.82 * pow(layer, 0.72)) * (0.55 + contourSpread * 0.45)
            let layerPhase = phase + layer * .pi * 2.0 + seedPhase * 0.19
            let m = harmonicA + (harmonicB - harmonicA) * (0.5 + 0.5 * sin(layerPhase)) * morphAmount
            let n1 = 0.34 + 1.20 * (0.5 + 0.5 * sin(phase + layer * .pi * 2.0 + seedPhase * 0.19 + 0.8))
            let n2 = 0.42 + 1.36 * (0.5 + 0.5 * cos(phase * 2.0 + layer * .pi * 2.0 + seedPhase * 0.19 + 1.3))
            let n3 = 0.42 + 1.36 * (0.5 + 0.5 * sin(phase * 3.0 + layer * .pi * 2.0 + seedPhase * 0.19 - 0.4))
            let layerRotation = rotation + layer * 0.38 + 0.16 * morphAmount * sin(layerPhase)
            let hue = Float(parameters.hueBaseDegrees) +
                Float(parameters.hueSpreadDegrees) * layer +
                18.0 * sin(layerPhase)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness)
            let layerAlpha = alpha * alphaBoost * (0.55 + 0.45 * layer)
            let pointSize = basePointSize * (0.78 + layer * 0.46 + morphAmount * 0.20)

            for pointIndex in 0..<pointsPerContour {
                let t = Float(pointIndex) / Float(pointsPerContour)
                let theta = t * .pi * 2.0
                let radius = superformulaRadius(theta: theta, m: m, n1: n1, n2: n2, n3: n3)
                let ripple = 1.0 + morphAmount * 0.10 * sin(theta * harmonicB + phase + layer)
                let localRadius = maxRadius * layerScale * radius * ripple
                let local = SIMD2<Float>(
                    cos(theta) * localRadius,
                    sin(theta) * localRadius
                )
                let screen = rotate(local, by: layerRotation) + center
                let pulse = 0.74 + morphAmount * 0.26 * (0.5 + 0.5 * sin(phase + theta * harmonicA + layer))
                vertices.append(FieldLinesVertex(
                    position: normalizedPosition(screen, width: width, height: height),
                    color: SIMD4<Float>(color.x, color.y, color.z, layerAlpha * pulse),
                    pointSize: pointSize * pulse
                ))
            }
        }

        return vertices
    }

    private func superformulaRadius(theta: Float, m: Float, n1: Float, n2: Float, n3: Float) -> Float {
        let a: Float = 1.0
        let b: Float = 1.0
        let partA = pow(abs(cos(m * theta / 4.0) / a), n2)
        let partB = pow(abs(sin(m * theta / 4.0) / b), n3)
        let denominator = max(0.0001, partA + partB)
        return min(1.85, pow(denominator, -1.0 / max(0.08, n1)))
    }

    private func rotate(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD2<Float>(
            point.x * c - point.y * s,
            point.x * s + point.y * c
        )
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

final class ProceduralPatternRenderer: RendererDiagnostics {
    var renderingError: Error?
    private let device: MTLDevice
    private let pointPipelineState: MTLRenderPipelineState
    private var schoolingSwarmSimulationCache: SchoolingSwarmSimulationCache?

    private struct SchoolingSwarmSimulationCache {
        var key: Key
        var positionsByStep: [[SIMD2<Float>]]
        var headingsByStep: [[Float]]

        struct Key: Equatable {
            var agentCount: Int
            var simulationResolution: Int
            var firstWaveDirection: Float
            var seedPhase: Float
            var horizontalRadius: Float
            var verticalRadius: Float
            var modulation: Float
            var maxRadius: Float
        }
    }

    init(device: MTLDevice, colorPixelFormat: MTLPixelFormat) throws {
        self.device = device

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let vertexFunction = library.makeFunction(name: "fieldLinesVertex"),
              let fragmentFunction = library.makeFunction(name: "fieldLinesFragment") else {
            throw RendererError.missingShaderFunction
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        pointPipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    func render(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        in view: MTKView,
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor
    ) {
        render(
            family: family,
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: view.drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    func render(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        outputTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        render(
            family: family,
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize,
            commandBuffer: commandBuffer,
            finalRenderPassDescriptor: renderPassDescriptor
        )
    }

    private func render(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize,
        commandBuffer: MTLCommandBuffer,
        finalRenderPassDescriptor: MTLRenderPassDescriptor
    ) {
        guard drawableSize.width > 1, drawableSize.height > 1 else { return }
        let vertices = makeVertices(
            family: family,
            parameters: parameters,
            seed: seed,
            frameIndex: frameIndex,
            clock: clock,
            drawableSize: drawableSize
        )
        do {
            try encodePointVertices(vertices, device: device, pipeline: pointPipelineState,
                                    commandBuffer: commandBuffer, descriptor: finalRenderPassDescriptor)
        } catch {
            renderingError = error
        }
    }

    fileprivate func makeVertices(
        family: RendererFamily,
        parameters: ProceduralPatternParameters,
        seed: UInt64,
        frameIndex: Int,
        clock: RenderClock,
        drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        let width = Float(drawableSize.width)
        let height = Float(drawableSize.height)
        let center = SIMD2<Float>(width * 0.5, height * 0.5)
        let scale = min(width, height) / 1080.0
        let elementCount = max(1, min(parameters.elementCount, 160))
        let samplesPerElement = max(2, min(parameters.samplesPerElement, 1600))
        let harmonicA: Float
        if family == .schoolingSwarm {
            harmonicA = Float(max(0, min(parameters.harmonicA, 15)))
        } else {
            harmonicA = Float(max(1, min(parameters.harmonicA, 32)))
        }
        let harmonicB = Float(max(1, min(parameters.harmonicB, 40)))
        let cycleCount = max(1, min(5, Int((parameters.speed * 2.0).rounded())))
        let phase = Float(clock.phase(frameIndex: frameIndex)) * Float(cycleCount)
        let seedPhase = Float(Double(seed % 10_000) / 10_000.0) * .pi * 2.0
        let maxRadius = min(width, height) * 0.64 * Float(clamp(parameters.scale, 0.1, 1.5))
        let modulation = Float(clamp(parameters.modulation, 0.0, 1.0))
        let depth = Float(clamp(parameters.depth, 0.0, 1.0))
        let feedback = Float(clamp(parameters.feedback, 0.0, 1.0))
        let alpha = Float(clamp(parameters.pointAlpha, 0.0, 1.0)) *
            Float(1.0 - clamp(parameters.fadeAlpha, 0.02, 0.98))
        let pointSize = Float(parameters.pointSize) * max(1.0, scale)
        let rotation = Float(parameters.rotation / 180.0 * Double.pi)
        let saturation = Float(clamp(parameters.saturation, 0.0, 1.0))
        let brightness = Float(clamp(parameters.brightness, 0.0, 1.4))

        var vertices: [FieldLinesVertex] = []
        vertices.reserveCapacity(elementCount * samplesPerElement)

        func appendVertex(_ screen: SIMD2<Float>, layer: Float, pulse: Float, sizeScale: Float = 1.0) {
            let hue = Float(parameters.hueBaseDegrees) +
                Float(parameters.hueSpreadDegrees) * layer +
                18.0 * sin(phase + layer * .pi * 2.0)
            let color = hsvToRGB(hueDegrees: hue, saturation: saturation, value: brightness * pulse)
            vertices.append(FieldLinesVertex(
                position: normalizedPosition(screen, width: width, height: height),
                color: SIMD4<Float>(color.x, color.y, color.z, alpha * (0.55 + 0.45 * pulse)),
                pointSize: pointSize * sizeScale * (0.72 + pulse * 0.38)
            ))
        }

        switch family {
        case .bloomingCircuits:
            makeBloomingCircuitsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .cellularBloom, .chromaticBloom:
            makeCellularBloomVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .chladniPlate:
            makeChladniPlateVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .circuitTracer:
            makeCircuitTracerVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .closedFlowParticles:
            makeClosedFlowVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .constellationDrift:
            makeConstellationDriftVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .crystalLattice, .vortexLattice:
            makeCrystalLatticeVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .dataMesh:
            makeDataMeshVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .electricStorm:
            makeElectricStormVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .sdfTunnel:
            makeSDFTunnelVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .feedbackSynth:
            makeFeedbackSynthVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                feedback: feedback,
                rotation: rotation
            )
        case .fireworksShow:
            makeFireworksShowVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .auroraCurtain:
            makeAuroraCurtainVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .cityLightsBokeh:
            makeCityLightsBokehVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .digitalSand:
            makeDigitalSandVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .inkInWater:
            makeInkInWaterVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .origamiTessellation:
            makeOrigamiTessellationVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .sakuraDrift:
            makeSakuraDriftVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .snowfallDepth:
            makeSnowfallDepthVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .solarCorona:
            makeSolarCoronaVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .underwaterCaustics:
            makeUnderwaterCausticsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .volumetricNebula:
            makeVolumetricNebulaVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .fluidNodes:
            makeFluidNodesVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .fourierKnots:
            makeFourierKnotsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .guillocheRose:
            makeGuillocheVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .growingNetwork:
            makeGrowingNetworkVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .instancedGeometry:
            makeInstancedGeometryVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .labyrinthTrace:
            makeLabyrinthTraceVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .laserRibbons, .photonStreams:
            makeLaserRibbonsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .luminousBubbles:
            makeLuminousBubblesVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .luminousStrings:
            makeLuminousStringsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .metaballField, .quantumFoam:
            makeMetaballVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .moireRings:
            makeMoireRingsVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .neonVortex, .stardustVortex:
            makeNeonVortexVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .particleFountain:
            makeParticleFountainVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .penroseTiling:
            makePenroseVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                modulation: modulation,
                rotation: rotation
            )
        case .pulseNetwork:
            makePulseNetworkVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .radialOscilloscope:
            makeRadialOscilloscopeVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .ribbonCascade:
            makeRibbonCascadeVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .scanlineTopography:
            makeScanlineTopographyVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .schoolingSwarm:
            makeSchoolingSwarmVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .rainCurtain:
            makeRainCurtainVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .truchetFlow:
            makeTruchetFlowVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                rotation: rotation
            )
        case .waveTerrain:
            makeWaveTerrainVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        case .wireframeMorph:
            makeWireframeMorphVertices(
                append: appendVertex,
                elementCount: elementCount,
                samplesPerElement: samplesPerElement,
                center: center,
                maxRadius: maxRadius,
                phase: phase,
                seedPhase: seedPhase,
                harmonicA: harmonicA,
                harmonicB: harmonicB,
                modulation: modulation,
                depth: depth,
                rotation: rotation
            )
        default:
            break
        }

        return vertices
    }

    private func makeBloomingCircuitsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let branchCount = max(12, min(72, elementCount))
        let samples = max(8, samplesPerElement)
        let phaseUnit = phase / (.pi * 2.0)
        for branch in 0..<branchCount {
            let layer = Float(branch) / Float(max(1, branchCount - 1))
            let laneSeed = seedPhase + Float(branch) * 17.173
            let trunkX = (fract(sin(laneSeed) * 49382.13) - 0.5) * maxRadius * 2.62
            let trunkY = (fract(cos(laneSeed * 0.73) * 39211.47) - 0.5) * maxRadius * 1.72
            let birth = fract(layer * 0.41 + seedPhase * 0.03)
            let age = fract(phaseUnit - birth + 1.0)
            let growth = min(1.0, age / (0.42 + modulation * 0.20))
            let life = smoothEnvelope(age, attack: 0.10, release: 0.92)
            if life <= 0.02 { continue }
            let direction = fract(sin(laneSeed * 1.9) * 79.31) > 0.5 ? Float(1.0) : Float(-1.0)
            let horizontal = maxRadius * (0.26 + depth * 0.20) * direction
            let vertical = maxRadius * (0.10 + modulation * 0.14) * sin(layer * harmonicA + phase)
            let corner = SIMD2<Float>(trunkX, trunkY)
            let elbow = corner + SIMD2<Float>(horizontal, vertical)
            let end = elbow + SIMD2<Float>(
                horizontal * (0.40 + 0.26 * sin(layer * harmonicB + phase)),
                maxRadius * (fract(cos(laneSeed * 2.1) * 61.9) - 0.5) * 0.38
            )
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                if t > growth { break }
                let pathT = t * 2.0
                let point = pathT < 1.0 ? corner + (elbow - corner) * pathT : elbow + (end - elbow) * (pathT - 1.0)
                append(rotate(point, by: rotation) + center, layer, 0.36 + life * 0.72, 0.78 + life * 0.66)
            }
            append(rotate(end, by: rotation) + center, layer, 0.52 + life * 0.70, 1.28 + life)
        }
    }

    private func makeCellularBloomVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(12, min(76, elementCount))
        let rows = max(8, min(48, samplesPerElement))
        let width = maxRadius * (2.84 + depth * 0.26)
        let height = maxRadius * (2.00 + depth * 0.28)
        let phaseUnit = fract(phase / (.pi * 2.0))
        for column in 0..<columns {
            let xLayer = Float(column) / Float(max(1, columns - 1))
            for row in 0..<rows {
                let yLayer = Float(row) / Float(max(1, rows - 1))
                let x = (xLayer - 0.5) * width
                let y = (yLayer - 0.5) * height
                let distance = hypot(xLayer - 0.5, yLayer - 0.5)
                let noise = fract(sin(Float(column) * 12.989 + Float(row) * 78.233) * 43758.54)
                let wave = fract(phaseUnit + distance * (1.5 + modulation * 1.1) - noise * 0.16)
                let pulse = exp(-pow((wave - 0.18) * (8.0 + depth * 8.0), 2.0))
                if pulse < 0.08 { continue }
                let local = SIMD2<Float>(
                    x + sin(phase + yLayer * harmonicA) * maxRadius * modulation * 0.018,
                    y + cos(phase + xLayer * harmonicB) * maxRadius * modulation * 0.018
                )
                append(rotate(local, by: rotation) + center, (xLayer + yLayer) * 0.5, 0.32 + pulse * 0.86, 0.92 + pulse * 1.20)
            }
        }
    }

    private func makeConstellationDriftVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let nodeCount = max(24, min(140, elementCount))
        let edgeSamples = max(5, min(28, samplesPerElement))
        var nodes: [SIMD2<Float>] = []
        nodes.reserveCapacity(nodeCount)
        for node in 0..<nodeCount {
            let id = Float(node)
            let a = fract(sin(seedPhase + id * 21.17) * 48291.3) * .pi * 2.0
            let r = sqrt(fract(cos(seedPhase * 0.83 + id * 39.7) * 19371.2)) * maxRadius * (1.10 + depth * 0.26)
            let drift = SIMD2<Float>(
                sin(phase * max(1.0, (harmonicA / 5.0).rounded()) + id * 0.33 * harmonicA / 5.0) * maxRadius * modulation * 0.10,
                cos(phase * max(1.0, (harmonicB / 7.0).rounded()) + id * 0.33 * harmonicB / 7.0) * maxRadius * modulation * 0.10
            )
            nodes.append(SIMD2<Float>(cos(a) * r * 1.42, sin(a) * r * 1.04) + drift)
        }
        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            let nodePulse = 0.82 + 0.18 * sin(phase + layer * .pi * 2.0)
            append(rotate(nodes[node], by: rotation) + center, layer, nodePulse, 1.58)
            let target = (node + Int(harmonicA) + Int(fract(sin(layer + seedPhase) * 7.0))) % nodeCount
            let distance = simd_length(nodes[target] - nodes[node]) / max(1.0, maxRadius)
            let edgePulse = max(0.0, 1.22 - distance) * (0.72 + 0.28 * sin(phase + layer * harmonicB))
            if edgePulse <= 0.06 { continue }
            for sample in 0..<edgeSamples {
                let t = Float(sample) / Float(max(1, edgeSamples - 1))
                let point = nodes[node] + (nodes[target] - nodes[node]) * t
                append(rotate(point, by: rotation) + center, layer, 0.44 + edgePulse * 0.72, 0.82 + edgePulse * 0.72)
            }
        }
    }

    private func makeParticleFountainVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let particleCount = max(36, min(150, elementCount))
        let trailSamples = max(4, min(24, samplesPerElement))
        let phaseUnit = phase / (.pi * 2.0)
        for particle in 0..<particleCount {
            let layer = Float(particle) / Float(max(1, particleCount - 1))
            let id = seedPhase + Float(particle) * 23.91
            let ageCycle = 1.0 + floor(fract(sin(id) * 4.0) * 2.0)
            let age = fract(phaseUnit * ageCycle + fract(cos(id) * 17.7))
            let side = fract(sin(id * 1.7) * 91.1) > 0.5 ? Float(1.0) : Float(-1.0)
            let launchX = (fract(cos(id * 0.47) * 142.7) - 0.5) * maxRadius * 0.62
            let velocityX = side * maxRadius * (0.46 + modulation * 0.34) * (0.45 + fract(sin(id * 2.1) * 0.7))
            let velocityY = maxRadius * (1.55 + depth * 0.60) * (0.72 + fract(cos(id * 2.3) * 0.42))
            for sample in 0..<trailSamples {
                let t = max(0.0, age - Float(sample) / Float(trailSamples) * 0.10)
                let x = launchX + velocityX * (t - 0.5)
                let y = maxRadius * 1.18 - velocityY * sin(t * .pi) + maxRadius * 0.08 * sin(phase + layer * harmonicA)
                let pulse = smoothEnvelope(age, attack: 0.06, release: 0.92) * pow(1.0 - Float(sample) / Float(trailSamples), 1.2)
                append(rotate(SIMD2<Float>(x, y), by: rotation) + center, layer, smoothEnvelope(age, attack: 0.06, release: 0.92) * 0.36 + pulse * 0.78, 0.76 + pulse * 0.96)
            }
        }
    }

    private func makePulseNetworkVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let nodeCount = max(18, min(110, elementCount))
        let edgeSamples = max(5, min(30, samplesPerElement))
        let phaseUnit = phase / (.pi * 2.0)
        var nodes: [SIMD2<Float>] = []
        nodes.reserveCapacity(nodeCount)
        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            let angle = layer * .pi * 2.0 * (1.0 + harmonicA * 0.04) + seedPhase
            let radius = maxRadius * (0.18 + sqrt(layer) * (1.18 + depth * 0.22))
            let wobble = maxRadius * modulation * 0.05 * sin(phase + layer * harmonicB)
            nodes.append(SIMD2<Float>(cos(angle) * (radius + wobble) * 1.30, sin(angle) * radius * 0.94))
        }
        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            append(rotate(nodes[node], by: rotation) + center, layer, 0.58, 0.88)
            for offset in [Int(harmonicA), Int(harmonicB)] {
                let target = (node + offset) % nodeCount
                let pulseCenter = fract(phaseUnit + layer * 0.63)
                for sample in 0..<edgeSamples {
                    let t = Float(sample) / Float(max(1, edgeSamples - 1))
                    let distance = abs(t - pulseCenter)
                    let wrappedDistance = min(distance, 1.0 - distance)
                    let pulse = exp(-pow(wrappedDistance * (12.0 + modulation * 10.0), 2.0))
                    let base = 0.22 + pulse * 0.90
                    let point = nodes[node] + (nodes[target] - nodes[node]) * t
                    append(rotate(point, by: rotation) + center, layer, base, 0.58 + pulse * 1.10)
                }
            }
        }
    }

    private func makeRibbonCascadeVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let ribbonCount = max(8, min(42, elementCount))
        for ribbon in 0..<ribbonCount {
            let layer = Float(ribbon) / Float(max(1, ribbonCount - 1))
            let lane = (layer - 0.5) * maxRadius * (2.10 + depth * 0.32)
            let ribbonPhase = seedPhase + layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let y = (t - 0.5) * maxRadius * 2.66
                let x = lane +
                    sin(t * .pi * 2.0 * harmonicA + phase + ribbonPhase) * maxRadius * modulation * 0.24 +
                    cos(t * .pi * 2.0 * harmonicB - phase) * maxRadius * modulation * 0.12
                let flow = wrapCentered(y + phase / (.pi * 2.0) * maxRadius * 2.66, span: maxRadius * 2.66)
                let life = LoopMath.lifetimeEnvelope(fract(t + phase / (.pi * 2.0)))
                append(rotate(SIMD2<Float>(x, flow), by: rotation) + center, layer, (0.58 + 0.42 * sin(t * .pi)) * life, 0.84 + modulation * 0.64)
            }
        }
    }

    private func makeScanlineTopographyVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let rows = max(22, min(112, elementCount))
        for row in 0..<rows {
            let layer = Float(row) / Float(max(1, rows - 1))
            let yBase = (layer - 0.5) * maxRadius * (2.18 + depth * 0.34)
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let x = (t - 0.5) * maxRadius * 3.30
                let ridgeA = sin(t * .pi * 2.0 * harmonicA + phase + layer * .pi)
                let ridgeB = cos(t * .pi * 2.0 * harmonicB - phase + layer * .pi * 2.0)
                let envelope = pow(sin(t * .pi), 0.34)
                let y = yBase + (ridgeA * 0.62 + ridgeB * 0.42) * maxRadius * modulation * 0.30 * envelope
                let pulse = 0.58 + 0.52 * abs(ridgeA * ridgeB)
                append(rotate(SIMD2<Float>(x, y), by: rotation) + center, layer, pulse, 1.00 + depth * 0.72)
            }
        }
    }

    private func makeDataMeshVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(10, min(48, elementCount))
        let rows = max(8, min(38, samplesPerElement))
        let width = maxRadius * (2.86 + depth * 0.26)
        let height = maxRadius * (2.00 + depth * 0.22)
        var nodes = Array(repeating: SIMD2<Float>.zero, count: columns * rows)

        func index(_ column: Int, _ row: Int) -> Int { row * columns + column }

        for row in 0..<rows {
            let yLayer = Float(row) / Float(max(1, rows - 1))
            for column in 0..<columns {
                let xLayer = Float(column) / Float(max(1, columns - 1))
                let wave = sin(xLayer * harmonicA * .pi * 2.0 + phase) *
                    cos(yLayer * harmonicB * .pi * 2.0 - phase)
                let warp = SIMD2<Float>(
                    sin(phase + yLayer * .pi * 2.0) * maxRadius * modulation * 0.035,
                    wave * maxRadius * modulation * (0.10 + depth * 0.06)
                )
                nodes[index(column, row)] = SIMD2<Float>(
                    (xLayer - 0.5) * width,
                    (yLayer - 0.5) * height
                ) + warp
            }
        }

        let edgeSamples = 5
        for row in 0..<rows {
            for column in 0..<columns {
                let layer = Float(row * columns + column) / Float(max(1, rows * columns - 1))
                let from = nodes[index(column, row)]
                let targets: [(Int, Int)] = [
                    (column + 1, row),
                    (column, row + 1),
                    (column + 1, row + 1)
                ]
                for target in targets where target.0 < columns && target.1 < rows {
                    let to = nodes[index(target.0, target.1)]
                    let pulse = 0.56 + 0.44 * sin(phase + layer * .pi * 2.0)
                    for sample in 0..<edgeSamples {
                        let t = Float(sample) / Float(edgeSamples - 1)
                        append(rotate(from + (to - from) * t, by: rotation) + center, layer, pulse, 0.74 + pulse * 0.36)
                    }
                }
            }
        }
    }

    private func makeFireworksShowVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let phaseUnit = fract(phase / (.pi * 2.0))
        let blackBoundary: Float = 0.0018
        guard phaseUnit > blackBoundary, phaseUnit < 1.0 - blackBoundary else { return }

        let shellCount = max(6, min(28, elementCount))
        let sparkCount = max(72, min(520, samplesPerElement))
        let launchDuration: Float = 0.052
        let baseSparkLife: Float = 0.128 + depth * 0.062
        let gravity = maxRadius * (0.92 + depth * 0.74)
        let drag: Float = 0.44 + modulation * 0.22
        let launchY = maxRadius * 1.08
        let minX = -maxRadius * 1.02
        let maxX = maxRadius * 1.02

        func emit(_ point: SIMD2<Float>, hue: Float, pulse: Float, size: Float) {
            append(point + center, hue, pulse, size)
        }

        for shell in 0..<shellCount {
            let layer = Float(shell) / Float(max(1, shellCount - 1))
            let shellSeed = seedPhase + Float(shell) * 31.731
            let shellType = shell % 7
            let sparkLifeMultiplier: Float
            switch shellType {
            case 2:
                sparkLifeMultiplier = 1.68
            case 3:
                sparkLifeMultiplier = 1.22
            case 6:
                sparkLifeMultiplier = 0.74
            default:
                sparkLifeMultiplier = 0.96 + 0.28 * fract(sin(shellSeed * 0.67) * 317.3)
            }
            let sparkLife = baseSparkLife * sparkLifeMultiplier
            let earliestLaunchStart: Float = 0.010
            let latestLaunchStart = max(
                earliestLaunchStart,
                1.0 - blackBoundary - 0.006 - launchDuration - sparkLife
            )
            let launchStart = earliestLaunchStart + layer * (latestLaunchStart - earliestLaunchStart)
            let burstTime = launchStart + launchDuration
            let endTime = burstTime + sparkLife
            guard phaseUnit >= launchStart, phaseUnit <= endTime else { continue }

            let xSeed = fract(sin(shellSeed * 0.43) * 43758.5453)
            let burstX = min(max((xSeed - 0.5) * maxRadius * (1.86 + modulation * 0.18), minX), maxX)
            let burstY = -maxRadius * (0.22 + 0.64 * fract(cos(shellSeed * 0.37) * 193.4))

            if phaseUnit < burstTime {
                let launchAge = max(0.0, min(1.0, (phaseUnit - launchStart) / launchDuration))
                let rocketY = launchY + (burstY - launchY) * launchAge
                let rocketX = burstX
                let trailSamples = 12
                for sample in 0..<trailSamples {
                    let trail = Float(sample) / Float(max(1, trailSamples - 1))
                    let fade = pow(1.0 - trail, 1.35) * launchAge
                    let point = SIMD2<Float>(
                        rocketX,
                        rocketY + maxRadius * 0.16 * trail
                    )
                    emit(point, hue: layer, pulse: 0.32 + fade * 0.76, size: 0.70 + fade * 0.92)
                }
                continue
            }

            let burstAge = max(0.0, min(1.0, (phaseUnit - burstTime) / sparkLife))
            let burnEnvelope = smoothEnvelope(burstAge, attack: 0.030, release: shellType == 2 ? 0.96 : 0.88)
            guard burnEnvelope > 0.001 else { continue }

            let burstCenter = SIMD2<Float>(burstX, burstY)
            let hueLayer = fract(layer + fract(sin(shellSeed) * 0.37))
            let isKiku = shellType == 0
            let isBotan = shellType == 1
            let isKamuro = shellType == 2
            let isSenrin = shellType == 3
            let isMangekyo = shellType == 4
            let isKatamono = shellType == 5
            let isHachi = shellType == 6

            for spark in 0..<sparkCount {
                let sparkLayer = Float(spark) / Float(max(1, sparkCount - 1))
                let id = shellSeed + Float(spark) * 19.193
                let angleSeed = fract(sin(id * 0.71) * 43758.5453)
                let radiusSeed = fract(cos(id * 0.53) * 18273.233)
                let sizeSeed = fract(sin(id * 1.97 + shellSeed * 0.13) * 25137.931)
                var theta = angleSeed * .pi * 2.0
                var localCenter = burstCenter
                var localAge = burstAge
                var radiusFactor = sqrt(radiusSeed)
                var fallStrength: Float = 0.20
                var tailEvery = 4
                var tailDelay: Float = 0.050
                var sparkHue = fract(hueLayer + sparkLayer * 0.16)
                var radialScale: Float = 0.72 + modulation * 0.30
                var shapeScale = SIMD2<Float>(1.0, 0.84 + depth * 0.18)
                var crackle: Float = 0.0
                var sizeMultiplier = 0.58 + pow(sizeSeed, 1.75) * 1.32

                if isKiku {
                    let spokeCount = max(36, min(96, Int(harmonicB) * 6))
                    let spoke = floor(angleSeed * Float(spokeCount))
                    theta = (spoke + 0.5 + (radiusSeed - 0.5) * 0.10) / Float(spokeCount) * .pi * 2.0
                    radiusFactor = 0.72 + radiusSeed * 0.30
                    fallStrength = 0.18
                    tailEvery = 2
                    tailDelay = 0.064
                    sizeMultiplier *= 0.88 + radiusSeed * 0.28
                } else if isBotan {
                    radiusFactor = 0.48 + sqrt(radiusSeed) * 0.52
                    fallStrength = 0.12
                    tailEvery = 12
                    tailDelay = 0.032
                    radialScale *= 0.92
                    sparkHue = fract(hueLayer + floor(sparkLayer * 3.0) * 0.08)
                    sizeMultiplier *= 1.12 + pow(sizeSeed, 2.0) * 0.38
                } else if isKamuro {
                    radiusFactor = 0.70 + radiusSeed * 0.34
                    fallStrength = 0.58
                    tailEvery = 1
                    tailDelay = 0.105
                    radialScale *= 0.96
                    sparkHue = 0.09 + fract(hueLayer * 0.08)
                    sizeMultiplier *= 0.66 + radiusSeed * 0.26
                } else if isSenrin {
                    let childCount = 7 + Int(abs(harmonicA).truncatingRemainder(dividingBy: 5))
                    let child = spark % childCount
                    let childTheta = (Float(child) / Float(childCount)) * .pi * 2.0 +
                        fract(sin(shellSeed * 0.29) * 2.0) * .pi
                    let childDistance = maxRadius * (0.18 + 0.14 * fract(cos(shellSeed + Float(child)) * 17.7))
                    localCenter = burstCenter + SIMD2<Float>(
                        cos(childTheta) * childDistance,
                        sin(childTheta) * childDistance * 0.76
                    )
                    localAge = max(0.0, min(1.0, (burstAge - 0.14) / 0.86))
                    guard burstAge > 0.10 else { continue }
                    theta = fract(angleSeed + Float(child) * 0.137) * .pi * 2.0
                    radiusFactor = 0.38 + radiusSeed * 0.58
                    fallStrength = 0.16
                    tailEvery = 5
                    tailDelay = 0.040
                    radialScale *= 0.56
                    sparkHue = fract(Float(child) / Float(childCount) + hueLayer * 0.18)
                    sizeMultiplier *= 0.54 + sizeSeed * 0.34
                } else if isMangekyo {
                    let petalCount = max(5, min(12, Int(harmonicA)))
                    let petal = floor(angleSeed * Float(petalCount))
                    theta = (petal + (radiusSeed - 0.5) * 0.26) / Float(petalCount) * .pi * 2.0
                    radiusFactor = 0.38 + abs(sin(radiusSeed * .pi)) * 0.62
                    fallStrength = 0.13
                    tailEvery = 3
                    radialScale *= 0.82
                    sparkHue = fract(hueLayer + petal / Float(petalCount) * 0.42)
                    sizeMultiplier *= 0.82 + abs(sin(petal)) * 0.24
                } else if isKatamono {
                    let ring = spark % 4
                    if ring == 0 {
                        theta = angleSeed * .pi * 2.0
                        radiusFactor = 0.92 + radiusSeed * 0.05
                        shapeScale = SIMD2<Float>(1.0, 0.54)
                    } else if ring == 1 {
                        theta = angleSeed * .pi * 2.0
                        radiusFactor = 0.50 + radiusSeed * 0.04
                    } else {
                        theta = (angleSeed < 0.5 ? 0.0 : .pi) + (radiusSeed - 0.5) * 0.18
                        radiusFactor = 0.28 + radiusSeed * 0.62
                        shapeScale = SIMD2<Float>(1.22, 0.24)
                    }
                    fallStrength = 0.10
                    tailEvery = 6
                    radialScale *= 0.86
                    sizeMultiplier *= ring == 0 ? 1.20 : 0.78 + radiusSeed * 0.30
                } else if isHachi {
                    let spin = localAge * .pi * (6.0 + Float(spark % 5))
                    theta = angleSeed * .pi * 2.0 + sin(spin + id) * 0.90
                    radiusFactor = 0.46 + radiusSeed * 0.48
                    fallStrength = 0.26
                    tailEvery = 3
                    crackle = max(0.0, sin((localAge * 13.0 + sparkLayer * harmonicB) * .pi))
                    radialScale *= 0.72
                    sizeMultiplier *= 0.44 + pow(sizeSeed, 0.65) * 1.26
                }

                let asymmetry = 1.0 + modulation * 0.04 * sin(theta * harmonicA + shellSeed)
                let initialSpeed = maxRadius * radialScale * radiusFactor * asymmetry
                let direction = SIMD2<Float>(
                    cos(theta) * shapeScale.x,
                    sin(theta) * shapeScale.y
                )
                let dragScale = max(0.14, 1.0 - drag * localAge * 0.40)
                let droop = gravity * localAge * localAge * fallStrength
                let turbulence = SIMD2<Float>(
                    sin(localAge * .pi * 2.0 + id) * maxRadius * modulation * (isHachi ? 0.024 : 0.006),
                    cos(localAge * .pi * 2.0 + id * 0.7) * maxRadius * modulation * (isHachi ? 0.018 : 0.005)
                )
                let sparkPosition = localCenter +
                    direction * initialSpeed * localAge * dragScale +
                    SIMD2<Float>(0, droop) +
                    turbulence
                let mouth = pow(max(0.0, 1.0 - abs(localAge - 0.58) * 0.32), 1.2)
                let twinkle = 0.78 + 0.22 * sin(localAge * .pi * 18.0 + id)
                let sizeBrightness = 0.78 + min(1.65, sizeMultiplier) * 0.16
                let pulse = burnEnvelope * mouth * (0.72 + 0.24 * twinkle + crackle * 0.28) * sizeBrightness
                let lifeSize = 0.56 + pow(1.0 - localAge, 0.72) * 0.72 + crackle * 0.46
                let size = max(0.30, lifeSize * sizeMultiplier)
                emit(
                    sparkPosition,
                    hue: sparkHue,
                    pulse: pulse,
                    size: size
                )

                if spark % tailEvery == 0 {
                    let trailSegments = isKamuro ? 6 : isKiku ? 5 : isBotan ? 2 : 4
                    for trailIndex in 1...trailSegments {
                        let trailFactor = Float(trailIndex) / Float(trailSegments)
                        let trailT = max(0.0, localAge - tailDelay * Float(trailIndex))
                        guard trailT < localAge else { continue }
                        let trailDrag = max(0.14, 1.0 - drag * trailT * 0.40)
                        let trailTurbulence = SIMD2<Float>(
                            sin(trailT * .pi * 2.0 + id) * maxRadius * modulation * (isHachi ? 0.018 : 0.004),
                            cos(trailT * .pi * 2.0 + id * 0.7) * maxRadius * modulation * (isHachi ? 0.014 : 0.003)
                        )
                        let trailPosition = localCenter +
                            direction * initialSpeed * trailT * trailDrag +
                            SIMD2<Float>(0, gravity * trailT * trailT * fallStrength) +
                            trailTurbulence
                        let trailPulseBase: Float = isKamuro ? 0.62 : isKiku ? 0.52 : isBotan ? 0.22 : 0.38
                        let trailPulse = pulse * trailPulseBase * pow(1.0 - trailFactor, 0.72)
                        emit(
                            trailPosition,
                            hue: sparkHue,
                            pulse: trailPulse,
                            size: size * (isKamuro ? 0.82 : 0.66) * (1.0 - trailFactor * 0.34)
                        )
                    }
                }
            }
        }
    }

    private func makeAuroraCurtainVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let curtains = max(12, min(72, elementCount))
        let samples = max(48, min(520, samplesPerElement))
        let width = maxRadius * 2.72
        let height = maxRadius * 2.04
        for curtain in 0..<curtains {
            let layer = Float(curtain) / Float(max(1, curtains - 1))
            let baseX = -width * 0.5 + width * layer
            let seed = seedPhase + Float(curtain) * 3.719
            let lanePhase = phase + seed
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let y = -height * 0.56 + height * t
                let waveA = sin(t * .pi * harmonicA + lanePhase)
                let waveB = sin(t * .pi * harmonicB - phase + seed * 0.41)
                let fold = sin((layer * 2.0 + t * 0.7) * .pi * 2.0 + phase)
                let x = baseX + (waveA * 0.10 + waveB * 0.055 + fold * 0.035) * width * modulation
                let verticalGlow = pow(max(0.0, sin(t * .pi)), 0.45)
                let pulse = verticalGlow * (0.34 + depth * 0.34 + 0.16 * sin(lanePhase + t * .pi * 4.0))
                append(rotate(SIMD2<Float>(x, y), by: rotation) + center, fract(layer * 0.45 + t * 0.16), pulse, 0.80 + verticalGlow * 0.74)
            }
        }
    }

    private func makeCityLightsBokehVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let lights = max(48, min(220, elementCount * 2))
        let ringSamples = max(6, min(28, samplesPerElement))
        let width = maxRadius * 2.82
        let height = maxRadius * 2.08
        for light in 0..<lights {
            let layer = Float(light) / Float(max(1, lights - 1))
            let seed = seedPhase + Float(light) * 8.193
            let x = (fract(sin(seed) * 43758.5453) - 0.5) * width
            let row = floor(fract(cos(seed * 0.77) * 193.4) * 14.0)
            let columnGlow = fract(sin(floor(layer * 21.0) + seedPhase) * 31.7)
            let yUnit = fract(row / 14.0 + columnGlow * 0.37 + fract(cos(seed * 1.41) * 11.7))
            let y = (yUnit - 0.5) * height + sin(layer * .pi * 2.0 + phase) * height * 0.014 * modulation
            let radius = maxRadius * (0.012 + depth * 0.034 + pow(fract(cos(seed * 1.31) * 719.2), 2.0) * 0.050)
            let blink = 0.58 + 0.42 * sin(phase * (1.0 + floor(fract(seed) * 3.0)) + seed)
            let pulse = 0.34 + max(0.0, blink) * (0.44 + modulation * 0.24)
            for sample in 0..<ringSamples {
                let t = Float(sample) / Float(ringSamples)
                let theta = t * .pi * 2.0
                let ring = sample == 0 ? 0.0 : radius * (0.38 + 0.62 * fract(sin(seed + Float(sample)) * 97.3))
                let point = SIMD2<Float>(x + cos(theta) * ring, y + sin(theta) * ring)
                append(rotate(point, by: rotation) + center, fract(layer * 0.12 + 0.08), pulse * (sample == 0 ? 1.0 : 0.38), sample == 0 ? 1.4 : 0.9)
            }
        }
    }

    private func makeDigitalSandVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let grains = max(400, min(3600, elementCount * max(4, samplesPerElement)))
        let width = maxRadius * 2.72
        let height = maxRadius * 2.02
        for grain in 0..<grains {
            let id = seedPhase + Float(grain) * 1.618
            let baseX = fract(sin(id) * 43758.5453)
            let baseY = fract(cos(id * 0.91) * 24634.6345)
            let lane = sin((baseY * harmonicA + phase / (.pi * 2.0)) * .pi * 2.0)
            let drift = sin(phase + baseX * .pi * 2.0 * harmonicB) * 0.055 * modulation
            let xUnit = fract(baseX + lane * 0.075 * modulation + drift + 1.0)
            let yUnit = fract(baseY + 0.045 * sin(phase + baseX * .pi * 6.0) * depth + 1.0)
            let point = SIMD2<Float>((xUnit - 0.5) * width, (yUnit - 0.5) * height)
            let pulse = 0.42 + 0.48 * pow(max(0.0, sin(baseY * .pi + phase + lane)), 2.0)
            append(rotate(point, by: rotation) + center, fract(baseY * 0.20 + 0.10), pulse, 0.62 + depth * 0.82)
        }
    }

    private func makeInkInWaterVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let blooms = max(12, min(72, elementCount))
        let samples = max(72, min(520, samplesPerElement))
        let width = maxRadius * 2.54
        let height = maxRadius * 1.94
        for bloom in 0..<blooms {
            let layer = Float(bloom) / Float(max(1, blooms - 1))
            let seed = seedPhase + Float(bloom) * 5.371
            let centerPoint = SIMD2<Float>(
                (fract(sin(seed) * 917.7) - 0.5) * width,
                (fract(cos(seed * 0.83) * 719.2) - 0.5) * height
            )
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let theta = t * .pi * 2.0
                let lobe = 0.58 + 0.42 * sin(theta * harmonicA + phase + seed)
                let smoke = 0.62 + 0.38 * sin(theta * harmonicB - phase + seed * 0.3)
                let radius = maxRadius * (0.08 + depth * 0.20) * lobe * smoke
                let swirl = theta + modulation * 0.85 * sin(phase + t * .pi * 2.0)
                let point = centerPoint + SIMD2<Float>(cos(swirl) * radius, sin(swirl) * radius * (0.72 + depth * 0.32))
                let pulse = smoothEnvelope(fract(t + phase / (.pi * 2.0) + layer), attack: 0.22, release: 0.96)
                append(rotate(point, by: rotation) + center, fract(layer * 0.36 + t * 0.08), 0.28 + pulse * 0.56, 0.90 + smoke * 0.74)
            }
        }
    }

    private func makeOrigamiTessellationVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(8, min(28, Int(sqrt(Float(elementCount))) + 8))
        let rows = max(6, min(22, columns * 3 / 4))
        let edgeSamples = max(4, min(18, samplesPerElement))
        let width = maxRadius * 2.60
        let height = maxRadius * 1.96
        for row in 0...rows {
            for column in 0...columns {
                let u = Float(column) / Float(max(1, columns))
                let v = Float(row) / Float(max(1, rows))
                let fold = sin((u * harmonicA + v * harmonicB) * .pi + phase + seedPhase)
                let base = SIMD2<Float>((u - 0.5) * width, (v - 0.5) * height)
                let offset = SIMD2<Float>(sin(phase + v * .pi * 2.0), cos(phase + u * .pi * 2.0)) * maxRadius * 0.020 * modulation * fold
                let p0 = base + offset
                let neighbors = [
                    SIMD2<Float>(width / Float(columns), 0),
                    SIMD2<Float>(0, height / Float(rows)),
                    SIMD2<Float>(width / Float(columns), height / Float(rows))
                ]
                for edge in neighbors {
                    guard column < columns || edge.x == 0 else { continue }
                    guard row < rows || edge.y == 0 else { continue }
                    for sample in 0..<edgeSamples {
                        let t = Float(sample) / Float(max(1, edgeSamples - 1))
                        let crease = sin((t + u + v) * .pi * 2.0 + phase)
                        let point = p0 + edge * t + SIMD2<Float>(0, crease * maxRadius * 0.014 * depth)
                        append(rotate(point, by: rotation) + center, fract((u + v) * 0.18 + edge.x * 0.001), 0.42 + abs(fold) * 0.46, 0.82 + abs(fold) * 0.58)
                    }
                }
            }
        }
    }

    private func makeSakuraDriftVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let petals = max(42, min(260, elementCount * 2))
        let width = maxRadius * 2.70
        let height = maxRadius * 2.06
        let phaseUnit = phase / (.pi * 2.0)
        for petal in 0..<petals {
            let layer = Float(petal) / Float(max(1, petals - 1))
            let seed = seedPhase + Float(petal) * 4.113
            let depthLayer = 0.35 + 0.65 * fract(sin(seed * 0.27) * 217.9)
            let fall = fract(fract(cos(seed * 0.71) * 193.4) + phaseUnit * (1.0 + floor(depthLayer * 2.0)))
            let sway = sin(phase + layer * .pi * 2.0 * harmonicA) * 0.08 * modulation
            let x = (fract(fract(sin(seed) * 43758.5453) + sway + 1.0) - 0.5) * width
            let y = (fall - 0.5) * height
            let angle = phase * (1.0 + floor(depthLayer * 2.0)) + seed
            let petalSize = maxRadius * (0.012 + depthLayer * 0.020)
            for sample in 0..<5 {
                let theta = Float(sample) / 5.0 * .pi * 2.0 + angle
                let r = petalSize * (sample == 0 ? 0.0 : 1.0)
                let point = SIMD2<Float>(x + cos(theta) * r, y + sin(theta) * r * 0.54)
                append(rotate(point, by: rotation) + center, fract(0.92 + layer * 0.05), (0.52 + depthLayer * 0.42) * LoopMath.lifetimeEnvelope(fall), 0.72 + depthLayer * 0.78)
            }
        }
    }

    private func makeSnowfallDepthVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let flakes = max(80, min(420, elementCount * 3))
        let width = maxRadius * 2.74
        let height = maxRadius * 2.08
        let phaseUnit = phase / (.pi * 2.0)
        for flake in 0..<flakes {
            let seed = seedPhase + Float(flake) * 6.171
            let z = 0.28 + 0.72 * fract(sin(seed * 1.31) * 97.3)
            let fall = fract(fract(cos(seed) * 811.3) + phaseUnit * (1.0 + floor(z * 2.0)))
            let wind = sin(phase + fall * .pi * 2.0 * harmonicA + seed) * 0.055 * modulation
            let x = (fract(fract(sin(seed * 0.83) * 43758.5453) + wind + 1.0) - 0.5) * width
            let y = (fall - 0.5) * height
            let size = 0.55 + z * 1.35
            let pulse = (0.44 + z * 0.50) * LoopMath.lifetimeEnvelope(fall)
            append(rotate(SIMD2<Float>(x, y), by: rotation) + center, fract(0.56 + z * 0.08), pulse, size)
            if flake % 3 == 0 {
                let delta = maxRadius * 0.010 * size
                append(rotate(SIMD2<Float>(x - delta, y), by: rotation) + center, fract(0.56 + z * 0.08), pulse * 0.42, size * 0.72)
                append(rotate(SIMD2<Float>(x + delta, y), by: rotation) + center, fract(0.56 + z * 0.08), pulse * 0.42, size * 0.72)
            }
        }
    }

    private func makeSolarCoronaVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let rays = max(48, min(180, elementCount * 2))
        let samples = max(32, min(260, samplesPerElement))
        for ray in 0..<rays {
            let layer = Float(ray) / Float(max(1, rays - 1))
            let seed = seedPhase + Float(ray) * 2.317
            let theta = layer * .pi * 2.0
            let flicker = 0.78 + 0.22 * sin(phase * 2.0 + seed)
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let ripple = sin(t * .pi * harmonicA + phase + seed) * 0.08 * modulation
                let flame = 1.0 + ripple + 0.08 * sin(theta * harmonicB - phase)
                let r = maxRadius * (0.08 + t * (1.18 + depth * 0.30)) * flame
                let bend = theta + sin(phase + t * .pi * 3.0 + seed) * 0.12 * modulation
                let point = SIMD2<Float>(cos(bend) * r, sin(bend) * r)
                let pulse = flicker * pow(max(0.0, 1.0 - t * 0.52), 0.85)
                append(rotate(point, by: rotation) + center, fract(0.04 + t * 0.10), pulse, 0.78 + (1.0 - t) * 0.72)
            }
        }
    }

    private func makeUnderwaterCausticsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let bands = max(18, min(96, elementCount))
        let samples = max(96, min(620, samplesPerElement))
        let width = maxRadius * 2.72
        let height = maxRadius * 2.02
        for band in 0..<bands {
            let layer = Float(band) / Float(max(1, bands - 1))
            let baseY = -height * 0.5 + height * layer
            let seed = seedPhase + Float(band) * 1.733
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let x = -width * 0.5 + width * t
                let wave = sin(t * .pi * harmonicA + phase + seed) + 0.55 * sin(t * .pi * harmonicB - phase + seed)
                let y = baseY + wave * maxRadius * (0.035 + modulation * 0.050)
                let focus = pow(max(0.0, 0.5 + 0.5 * sin(wave * .pi + phase)), 2.0)
                append(rotate(SIMD2<Float>(x, y), by: rotation) + center, fract(0.48 + layer * 0.12), 0.30 + focus * (0.54 + depth * 0.20), 0.68 + focus * 0.72)
            }
        }
    }

    private func makeVolumetricNebulaVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let clouds = max(12, min(90, elementCount))
        let samples = max(50, min(260, samplesPerElement))
        let width = maxRadius * 2.58
        let height = maxRadius * 1.98
        for cloud in 0..<clouds {
            let layer = Float(cloud) / Float(max(1, clouds - 1))
            let seed = seedPhase + Float(cloud) * 9.173
            let orbit = sin(phase) * (.pi * 2.0) * (0.18 + 0.08 * fract(seed)) + seed
            let cloudCenter = SIMD2<Float>(
                (fract(sin(seed) * 43758.5453) - 0.5) * width + cos(orbit) * maxRadius * 0.10 * modulation,
                (fract(cos(seed * 0.61) * 24634.6345) - 0.5) * height + sin(orbit) * maxRadius * 0.08 * modulation
            )
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let theta = fract(sin(seed + Float(sample) * 1.37) * 719.2) * .pi * 2.0 + sin(phase) * (.pi * 2.0) * 0.18
                let radial = sqrt(fract(cos(seed * 0.73 + Float(sample)) * 431.8))
                let lobe = 0.66 + 0.34 * sin(theta * harmonicA + phase + seed)
                let r = maxRadius * (0.08 + depth * 0.18) * radial * lobe
                let point = cloudCenter + SIMD2<Float>(cos(theta) * r, sin(theta) * r * (0.72 + depth * 0.34))
                let glow = smoothEnvelope(fract(t + sin(phase) * 0.18 + layer), attack: 0.18, release: 0.96)
                append(rotate(point, by: rotation) + center, fract(layer * 0.50 + t * 0.18), 0.24 + glow * 0.62, 0.92 + radial * 1.10)
            }
        }
    }

    private func makeFluidNodesVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let nodeCount = max(18, min(110, elementCount))
        let edgeSamples = max(4, min(24, samplesPerElement))
        var nodes: [SIMD2<Float>] = []
        nodes.reserveCapacity(nodeCount)

        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            let seed = seedPhase + Float(node) * 13.73
            let angle = fract(sin(seed) * 173.3) * .pi * 2.0
            let radius = sqrt(fract(cos(seed * 1.37) * 419.8)) * maxRadius * (0.88 + depth * 0.32)
            let flow = SIMD2<Float>(
                sin(phase + layer * harmonicA + seed) * maxRadius * modulation * 0.16,
                cos(phase + layer * harmonicB - seed) * maxRadius * modulation * 0.16
            )
            nodes.append(SIMD2<Float>(cos(angle) * radius * 1.34, sin(angle) * radius * 0.96) + flow)
        }

        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            let pulse = 0.60 + 0.40 * sin(phase + layer * .pi * 2.0)
            append(rotate(nodes[node], by: rotation) + center, layer, pulse, 1.28 + depth * 0.72)
            for offset in [1, Int(harmonicA)] {
                let target = (node + offset) % nodeCount
                let distance = simd_length(nodes[target] - nodes[node]) / max(1.0, maxRadius)
                let edgePulse = max(0.0, 1.10 - distance) * (0.52 + 0.48 * pulse)
                if edgePulse < 0.14 { continue }
                for sample in 0..<edgeSamples {
                    let t = Float(sample) / Float(max(1, edgeSamples - 1))
                    let bend = sin(t * .pi) * maxRadius * modulation * 0.035
                    let normal = normalizeOrZero(SIMD2<Float>(-(nodes[target] - nodes[node]).y, (nodes[target] - nodes[node]).x))
                    let point = nodes[node] + (nodes[target] - nodes[node]) * t + normal * bend
                    append(rotate(point, by: rotation) + center, layer, 0.32 + edgePulse * 0.66, 0.66 + edgePulse * 0.54)
                }
            }
        }
    }

    private func makeLuminousBubblesVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let bubbleCount = max(18, min(72, elementCount))
        let ringSamples = max(32, min(220, samplesPerElement))
        let phaseUnit = phase / (.pi * 2.0)
        let horizontalSpan = maxRadius * (2.36 + depth * 0.34)
        let verticalSpan = maxRadius * (1.78 + depth * 0.28)

        for bubble in 0..<bubbleCount {
            let layer = Float(bubble) / Float(max(1, bubbleCount - 1))
            let seed = seedPhase + Float(bubble) * 29.17
            let birth = fract(sin(seed * 0.41) * 319.7)
            let age = fract(phaseUnit - birth + 1.0)
            let easedAge = age * age * (3.0 - 2.0 * age)
            let life = smoothEnvelope(age, attack: 0.08, release: 0.90)
            let xSeed = fract(cos(seed * 0.73) * 811.3)
            let swaySeed = fract(sin(seed * 1.29) * 541.8)
            let x = (xSeed - 0.5) * horizontalSpan +
                sin(phase + seed + swaySeed * .pi * 2.0) * maxRadius * modulation * 0.14
            let y = verticalSpan * (0.58 - easedAge * 1.16)
            let bubbleCenter = SIMD2<Float>(x, y)
            let baseRadius = maxRadius * (0.018 + 0.026 * fract(cos(seed * 0.71) * 57.2))
            let radius = baseRadius * (0.62 + easedAge * (3.25 + depth * 1.10))

            for sample in 0..<ringSamples {
                let t = Float(sample) / Float(max(1, ringSamples - 1))
                let theta = t * .pi * 2.0
                let ripple = 1.0 + modulation * 0.08 * sin(theta * harmonicB + phase + seed)
                let local = bubbleCenter + SIMD2<Float>(cos(theta) * radius * ripple, sin(theta) * radius * ripple)
                let highlight = max(0.0, sin(theta + 0.65) * 0.5 + 0.5)
                append(rotate(local, by: rotation) + center, layer, life * (0.56 + highlight * 0.40), 0.74 + depth * 0.54)
            }

            let shine = bubbleCenter + SIMD2<Float>(-radius * 0.28, -radius * 0.32)
            append(rotate(shine, by: rotation) + center, layer, life * 0.86, 1.72 + depth * 0.92)
            append(rotate(bubbleCenter, by: rotation) + center, layer, life * 0.34, 1.18 + depth * 0.68)
        }
    }

    private func makeSchoolingSwarmVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let agentCount = max(72, min(120, elementCount))
        let bodySamples = max(5, min(12, samplesPerElement))
        let horizontalRadius = maxRadius * (1.02 + depth * 0.26)
        let verticalRadius = maxRadius * (0.74 - depth * 0.48)
        let phaseUnit = fract(phase / (.pi * 2.0))
        let simulationResolution = 144
        let simulationSteps = max(0, min(simulationResolution, Int(floor(phaseUnit * Float(simulationResolution)))))
        let swimSpeed = maxRadius * (0.010 + modulation * 0.006)
        let repulsionRadius = maxRadius * 0.105
        let alignmentRadius = maxRadius * 0.235
        let attractionRadius = maxRadius * 0.38
        let repulsionRadiusSquared = repulsionRadius * repulsionRadius
        let alignmentRadiusSquared = alignmentRadius * alignmentRadius
        let attractionRadiusSquared = attractionRadius * attractionRadius
        let attractionInnerRadiusSquared = alignmentRadius * 0.74 * alignmentRadius * 0.74
        let waveCycleCount = 4.0

        func shortestAngle(_ from: Float, _ to: Float) -> Float {
            wrapCentered(to - from, span: .pi * 2.0)
        }

        func mixedHeading(_ current: Float, toward target: Float, amount: Float) -> Float {
            current + shortestAngle(current, target) * max(0.0, min(1.0, amount))
        }

        func baseHeading(at unitTime: Float) -> Float {
            let localPhase = unitTime * .pi * 2.0
            return sin(localPhase + seedPhase) * 0.34 +
                sin(localPhase * 2.0 - seedPhase * 0.61) * 0.18
        }

        func waveState(at unitTime: Float) -> (direction: SIMD2<Float>, progress: Float, envelope: Float) {
            let wavePosition = unitTime * Float(waveCycleCount)
            let waveIndex = floor(wavePosition)
            let progress = fract(wavePosition)
            let baseDirection = harmonicA
            let offsetIndex = max(0, min(3, Int(waveIndex)))
            let directionOffset: Float
            switch offsetIndex {
            case 0:
                directionOffset = 0.0
            case 1:
                directionOffset = 4.0
            case 2:
                directionOffset = 1.0
            default:
                directionOffset = 5.0
            }
            let directionIndex = (baseDirection + directionOffset).truncatingRemainder(dividingBy: 8.0)
            let angle = directionIndex * (.pi / 4.0)
            let envelope = sin(progress * .pi)
            return (SIMD2<Float>(cos(angle), sin(angle)), progress, max(0.0, envelope))
        }

        func smooth(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
            let t = min(max((value - edge0) / max(0.0001, edge1 - edge0), 0.0), 1.0)
            return t * t * (3.0 - 2.0 * t)
        }

        let cacheKey = SchoolingSwarmSimulationCache.Key(
            agentCount: agentCount,
            simulationResolution: simulationResolution,
            firstWaveDirection: harmonicA,
            seedPhase: seedPhase,
            horizontalRadius: horizontalRadius,
            verticalRadius: verticalRadius,
            modulation: modulation,
            maxRadius: maxRadius
        )
        let cache: SchoolingSwarmSimulationCache
        if let existingCache = schoolingSwarmSimulationCache, existingCache.key == cacheKey {
            cache = existingCache
        } else {
            var simulatedPositions = Array(repeating: SIMD2<Float>.zero, count: agentCount)
            var simulatedHeadings = Array(repeating: Float.zero, count: agentCount)
            var positionsByStep: [[SIMD2<Float>]] = []
            var headingsByStep: [[Float]] = []
            positionsByStep.reserveCapacity(simulationResolution + 1)
            headingsByStep.reserveCapacity(simulationResolution + 1)

            for agent in 0..<agentCount {
                let id = seedPhase + Float(agent) * 17.913
                let radial = sqrt(fract(sin(id * 0.73) * 43758.5453))
                let angle = fract(cos(id * 1.17) * 24634.6345) * .pi * 2.0
                simulatedPositions[agent] = SIMD2<Float>(
                    cos(angle) * radial * horizontalRadius * 0.86,
                    sin(angle) * radial * verticalRadius * 0.86
                )
                simulatedHeadings[agent] = baseHeading(at: 0) +
                    sin(id * 0.31) * 0.18 +
                    cos(id * 0.47) * 0.12
            }

            positionsByStep.append(simulatedPositions)
            headingsByStep.append(simulatedHeadings)

            for step in 1...simulationResolution {
                let unitTime = Float(step) / Float(simulationResolution)
                let oldPositions = simulatedPositions
                let oldHeadings = simulatedHeadings
                let oldHeadingVectors = oldHeadings.map { SIMD2<Float>(cos($0), sin($0)) }
                let wave = waveState(at: unitTime)
                let waveExtent = max(1.0, horizontalRadius * 1.42)

                for agent in 0..<agentCount {
                    var repulsion = SIMD2<Float>.zero
                    var attraction = SIMD2<Float>.zero
                    var alignVector = SIMD2<Float>.zero
                    var neighborCount: Float = 0
                    var attractionCount: Float = 0

                    for other in 0..<agentCount where other != agent {
                        let delta = oldPositions[other] - oldPositions[agent]
                        let distanceSquared = dot(delta, delta)
                        guard distanceSquared > 0.000001, distanceSquared < attractionRadiusSquared else { continue }
                        let distance = sqrt(distanceSquared)
                        let direction = delta / distance

                        if distanceSquared < repulsionRadiusSquared {
                            repulsion -= direction * ((repulsionRadius - distance) / repulsionRadius)
                        }
                        if distanceSquared < alignmentRadiusSquared {
                            alignVector += oldHeadingVectors[other]
                            neighborCount += 1.0
                        }
                        if distanceSquared > attractionInnerRadiusSquared {
                            attraction += direction
                            attractionCount += 1.0
                        }
                    }

                    let waveCoordinate = min(1.0, max(0.0, dot(oldPositions[agent], wave.direction) / waveExtent * 0.5 + 0.5))
                    let waveDelta = waveCoordinate - wave.progress
                    let escapeWave = exp(-waveDelta * waveDelta * (56.0 + modulation * 36.0)) * wave.envelope
                    var desiredVector = oldHeadingVectors[agent]

                    if neighborCount > 0 {
                        desiredVector += normalizeOrZero(alignVector / neighborCount) * (0.74 + modulation * 0.42)
                    }
                    if attractionCount > 0 {
                        desiredVector += normalizeOrZero(attraction / attractionCount) * 0.28
                    }
                    desiredVector += repulsion * 1.55
                    desiredVector += normalizeOrZero(-oldPositions[agent]) * 0.18
                    desiredVector += wave.direction * escapeWave * (1.55 + modulation * 0.92)

                    let desiredHeading = atan2(desiredVector.y, desiredVector.x)
                    let response = 0.075 + 0.38 * escapeWave
                    let newHeading = mixedHeading(oldHeadings[agent], toward: desiredHeading, amount: response)
                    let velocity = SIMD2<Float>(cos(newHeading), sin(newHeading)) * swimSpeed
                    var newPosition = oldPositions[agent] + velocity

                    let ellipseValue = (newPosition.x * newPosition.x) / max(1.0, horizontalRadius * horizontalRadius) +
                        (newPosition.y * newPosition.y) / max(1.0, verticalRadius * verticalRadius)
                    if ellipseValue > 1.0 {
                        newPosition += normalizeOrZero(-newPosition) * swimSpeed * (0.6 + ellipseValue * 0.5)
                    }

                    simulatedPositions[agent] = newPosition
                    simulatedHeadings[agent] = newHeading
                }

                positionsByStep.append(simulatedPositions)
                headingsByStep.append(simulatedHeadings)
            }

            cache = SchoolingSwarmSimulationCache(
                key: cacheKey,
                positionsByStep: positionsByStep,
                headingsByStep: headingsByStep
            )
            schoolingSwarmSimulationCache = cache
        }

        var positions = cache.positionsByStep[simulationSteps]
        var headings = cache.headingsByStep[simulationSteps]
        let initialPositions = cache.positionsByStep[0]
        let initialHeadings = cache.headingsByStep[0]

        let loopBlend = smooth(0.58, 1.0, phaseUnit)
        if loopBlend > 0 {
            for agent in 0..<agentCount {
                positions[agent] = positions[agent] * (1.0 - loopBlend) + initialPositions[agent] * loopBlend
                headings[agent] = mixedHeading(headings[agent], toward: initialHeadings[agent], amount: loopBlend)
            }
        }

        for agent in 0..<agentCount {
            let layer = Float(agent) / Float(max(1, agentCount - 1))
            let id = seedPhase + Float(agent) * 17.913
            let localHeading = headings[agent]
            let localDirection = SIMD2<Float>(cos(localHeading), sin(localHeading))
            let localNormal = SIMD2<Float>(-localDirection.y, localDirection.x)
            let distanceFromCenter = min(1.0, simd_length(positions[agent]) / max(1.0, horizontalRadius))
            let body = maxRadius * (0.020 + 0.010 * (1.0 - distanceFromCenter))
            let base = positions[agent]
            let tail = base - localDirection * body * 1.42
            let nose = base + localDirection * body * 1.66

            for sample in 0..<bodySamples {
                let t = Float(sample) / Float(max(1, bodySamples - 1))
                let width = sin(t * .pi) * body * 0.18
                let point = tail + (nose - tail) * t + localNormal * width * sin(phase * 5.0 + id)
                append(
                    rotate(point, by: rotation) + center,
                    layer,
                    0.64 + 0.22 * (1.0 - distanceFromCenter),
                    0.88 + (1.0 - distanceFromCenter) * 0.30
                )
            }

            let tailBeat = sin(phase * 6.0 + id) * body * 0.44
            let upperTail = tail + localNormal * (body * 0.72 + tailBeat)
            let lowerTail = tail - localNormal * (body * 0.72 - tailBeat)
            append(rotate(upperTail, by: rotation) + center, layer, 0.72, 0.82)
            append(rotate(lowerTail, by: rotation) + center, layer, 0.72, 0.82)
            let nosePoint = rotate(nose, by: rotation) + center
            append(nosePoint, layer, 0.86, 1.02)
        }
    }

    private func makeWireframeMorphVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(6, min(36, elementCount))
        let rows = max(6, min(36, samplesPerElement))
        let width = maxRadius * (2.48 + depth * 0.34)
        let height = maxRadius * (1.84 + depth * 0.28)
        var nodes = Array(repeating: SIMD2<Float>.zero, count: columns * rows)

        func index(_ column: Int, _ row: Int) -> Int { row * columns + column }

        for row in 0..<rows {
            let yLayer = Float(row) / Float(max(1, rows - 1))
            for column in 0..<columns {
                let xLayer = Float(column) / Float(max(1, columns - 1))
                let x = (xLayer - 0.5) * width
                let y = (yLayer - 0.5) * height
                let z = sin(xLayer * harmonicA * .pi * 2.0 + phase) *
                    cos(yLayer * harmonicB * .pi * 2.0 - phase)
                let perspective = 1.0 + z * depth * 0.16
                let twist = seedPhase * 0.04 +
                    sin(phase) * (0.26 + modulation * 0.12) +
                    z * modulation * 0.18
                nodes[index(column, row)] = rotate(SIMD2<Float>(x * perspective, y * perspective), by: twist)
            }
        }

        let edgeSamples = 6
        for row in 0..<rows {
            for column in 0..<columns {
                let layer = Float(row * columns + column) / Float(max(1, rows * columns - 1))
                let targets: [(Int, Int)] = [(column + 1, row), (column, row + 1), (column + 1, row + 1)]
                for target in targets where target.0 < columns && target.1 < rows {
                    let from = nodes[index(column, row)]
                    let to = nodes[index(target.0, target.1)]
                    let pulse = 0.58 + 0.42 * sin(phase + layer * .pi * 2.0)
                    for sample in 0..<edgeSamples {
                        let t = Float(sample) / Float(edgeSamples - 1)
                        append(rotate(from + (to - from) * t, by: rotation) + center, layer, pulse, 0.78 + pulse * 0.46)
                    }
                }
            }
        }
    }

    private func makeClosedFlowVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for element in 0..<elementCount {
            let layer = Float(element) / Float(max(1, elementCount - 1))
            let offset = layer * .pi * 2.0 + seedPhase
            let baseRadius = maxRadius * (0.12 + 0.86 * layer)
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let theta = t * .pi * 2.0
                let curl = modulation * 0.22 * sin(theta * harmonicA + phase + offset)
                let angle = theta + offset * 0.13 + curl + phase
                let radius = baseRadius * (0.78 + 0.22 * sin(theta * harmonicB - phase + offset))
                let drift = SIMD2<Float>(
                    cos(theta * 2.0 + phase + offset),
                    sin(theta * 3.0 - phase + offset)
                ) * maxRadius * modulation * 0.10
                let screen = rotate(SIMD2<Float>(cos(angle) * radius, sin(angle) * radius) + drift, by: rotation) + center
                append(screen, layer, 0.65 + 0.35 * sin(theta + phase + offset) * 0.5 + 0.35, 1.0)
            }
        }
    }

    private func makeChladniPlateVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(24, min(150, elementCount))
        let rows = max(24, min(150, samplesPerElement))
        let xScale = maxRadius * 2.86
        let yScale = maxRadius * (2.22 + depth * 0.34)
        for column in 0..<columns {
            let xLayer = Float(column) / Float(max(1, columns - 1))
            let x = (xLayer - 0.5) * xScale
            for row in 0..<rows {
                let yLayer = Float(row) / Float(max(1, rows - 1))
                let y = (yLayer - 0.5) * yScale
                let nx = (xLayer - 0.5) * 2.0
                let ny = (yLayer - 0.5) * 2.0
                let modeA = sin(nx * harmonicA * .pi + phase)
                let modeB = sin(ny * harmonicB * .pi - phase)
                let diagonal = sin((nx + ny) * .pi * (harmonicA + harmonicB) * 0.5 + phase)
                let field = abs(modeA * modeB + diagonal * modulation * 0.34)
                let threshold = 0.20 + modulation * 0.16
                if field < threshold {
                    let pulse = 1.0 - min(1.0, field / threshold)
                    let local = SIMD2<Float>(x, y)
                    append(rotate(local, by: rotation) + center, (xLayer + yLayer) * 0.5, 0.70 + 0.30 * pulse, 1.00 + pulse * 0.62)
                }
            }
        }
    }

    private func makeCircuitTracerVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let gridColumns = max(7, min(18, Int(harmonicA) + 8))
        let gridRows = max(5, min(14, Int(harmonicB) + 4))
        let routeCount = max(8, min(72, elementCount))
        let samples = max(6, samplesPerElement)
        let width = maxRadius * (2.46 + depth * 0.42)
        let height = maxRadius * (1.62 + depth * 0.28)
        let phaseUnit = phase / (.pi * 2.0)

        for route in 0..<routeCount {
            let layer = Float(route) / Float(max(1, routeCount - 1))
            let routeSeed = seedPhase + Float(route) * 12.9898
            let startColumn = Int(floor(fract(sin(routeSeed) * 43758.5453) * Float(gridColumns)))
            let startRow = Int(floor(fract(cos(routeSeed * 1.37) * 24634.6345) * Float(gridRows)))
            let segmentCount = max(3, min(9, 3 + Int(fract(sin(routeSeed * 0.41) * 531.7) * 6.0)))
            var previous = SIMD2<Float>(
                (Float(startColumn) / Float(max(1, gridColumns - 1)) - 0.5) * width,
                (Float(startRow) / Float(max(1, gridRows - 1)) - 0.5) * height
            )

            for segment in 0..<segmentCount {
                let turn = fract(sin(routeSeed + Float(segment) * 3.17) * 913.13)
                let stepColumn = Int(floor(fract(turn + layer * 0.37) * Float(gridColumns)))
                let stepRow = Int(floor(fract(turn * 1.91 + 0.23) * Float(gridRows)))
                let next: SIMD2<Float>
                if segment % 2 == 0 {
                    next = SIMD2<Float>(
                        (Float(stepColumn) / Float(max(1, gridColumns - 1)) - 0.5) * width,
                        previous.y
                    )
                } else {
                    next = SIMD2<Float>(
                        previous.x,
                        (Float(stepRow) / Float(max(1, gridRows - 1)) - 0.5) * height
                    )
                }

                let routePhase = fract(phaseUnit + layer + Float(segment) / Float(max(1, segmentCount)))
                for sample in 0..<samples {
                    let t = Float(sample) / Float(max(1, samples - 1))
                    let pulseDistance = min(abs(t - routePhase), 1.0 - abs(t - routePhase))
                    let pulse = max(0.0, 1.0 - pulseDistance * (7.0 + modulation * 9.0))
                    let baseGlow = 0.22 + pulse * 0.84
                    let point = previous + (next - previous) * t
                    let jitter = SIMD2<Float>(
                        sin(routeSeed + t * .pi * 2.0) * maxRadius * modulation * 0.006,
                        cos(routeSeed * 0.7 + t * .pi * 2.0) * maxRadius * modulation * 0.006
                    )
                    append(
                        rotate(point + jitter, by: rotation) + center,
                        layer,
                        baseGlow,
                        0.90 + pulse * 1.10
                    )
                }

                if routePhase > 0.72 {
                    append(rotate(next, by: rotation) + center, layer, 1.08, 1.65)
                }

                previous = next
            }
        }
    }

    private func makeCrystalLatticeVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(6, min(96, elementCount))
        let rows = max(6, min(96, samplesPerElement))
        let xScale = maxRadius * (2.72 + depth * 0.36)
        let yScale = maxRadius * (2.12 + depth * 0.34)
        for column in 0..<columns {
            let columnLayer = Float(column) / Float(max(1, columns - 1))
            for row in 0..<rows {
                let rowLayer = Float(row) / Float(max(1, rows - 1))
                let x = (columnLayer - 0.5) * xScale
                let y = (rowLayer - 0.5) * yScale
                let stagger = (row % 2 == 0 ? -0.5 : 0.5) * xScale / Float(columns) * 0.42
                let wave = sin((columnLayer * harmonicA + rowLayer * harmonicB) * .pi * 2.0 + phase + seedPhase)
                let shimmer = cos((columnLayer - rowLayer) * .pi * 2.0 * harmonicB - phase)
                let offset = SIMD2<Float>(
                    shimmer * maxRadius * modulation * 0.028,
                    wave * maxRadius * modulation * 0.036
                )
                let local = SIMD2<Float>(x + stagger, y) + offset
                let layer = (columnLayer + rowLayer) * 0.5
                append(
                    rotate(local, by: rotation + sin(phase) * 0.05) + center,
                    layer,
                    0.76 + 0.34 * abs(wave),
                    1.14 + depth * 0.72
                )
            }
        }
    }

    private func makeElectricStormVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let boltCount = max(12, elementCount)
        let samples = max(24, samplesPerElement)
        for bolt in 0..<boltCount {
            let layer = Float(bolt) / Float(max(1, boltCount - 1))
            let baseAngle = layer * .pi * 2.0 + seedPhase + sin(phase + layer * harmonicB) * 0.22
            let branchPhase = seedPhase * 0.31 + Float(bolt) * 1.713
            let startRadius = maxRadius * (0.08 + 0.14 * sin(branchPhase))
            let endRadius = maxRadius * (0.76 + depth * 0.58)
            for sample in 0..<samples {
                let t = Float(sample) / Float(max(1, samples - 1))
                let fork = sin(t * .pi * harmonicA + phase + branchPhase)
                let jitter = sin(t * .pi * harmonicB - phase * 2.0 + branchPhase) * modulation
                let angle = baseAngle + fork * 0.18 + jitter * 0.22
                let radius = startRadius + (endRadius - startRadius) * t
                let sideFlash = SIMD2<Float>(
                    cos(baseAngle + .pi * 0.5),
                    sin(baseAngle + .pi * 0.5)
                ) * maxRadius * jitter * 0.10
                let local = SIMD2<Float>(cos(angle) * radius * 1.34, sin(angle) * radius) + sideFlash
                append(
                    rotate(local, by: rotation) + center,
                    layer,
                    0.72 + 0.28 * abs(fork),
                    1.08 + (1.0 - t) * 0.42
                )
            }
        }
    }

    private func makeSDFTunnelVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        for ring in 0..<elementCount {
            let layer = Float(ring) / Float(max(1, elementCount - 1))
            let zPulse = 0.5 + 0.5 * sin(phase + layer * .pi * 2.0)
            let perspective = 0.16 + pow(layer, 1.25) * (0.70 + depth * 0.35)
            let ringRadius = maxRadius * perspective * (0.82 + 0.18 * zPulse)
            let ringRotation = rotation + phase + layer * 0.7 + seedPhase * 0.03
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(samplesPerElement)
                let theta = t * .pi * 2.0
                let facets = 1.0 + modulation * 0.12 * sin(theta * harmonicA + phase + layer * harmonicB)
                let local = SIMD2<Float>(
                    cos(theta) * ringRadius * facets,
                    sin(theta) * ringRadius * facets * (0.74 + depth * 0.26)
                )
                append(rotate(local, by: ringRotation) + center, layer, 0.62 + 0.38 * zPulse, 0.8 + layer * 0.8)
            }
        }
    }

    private func makeFeedbackSynthVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        feedback: Float,
        rotation: Float
    ) {
        for echo in 0..<elementCount {
            let layer = Float(echo) / Float(max(1, elementCount - 1))
            let echoScale = pow(1.0 - layer * 0.74, 1.0 + feedback)
            let echoRotation = rotation + layer * (.pi * 1.8 + feedback * .pi) + phase
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(samplesPerElement)
                let theta = t * .pi * 2.0
                let rose = 0.55 + 0.45 * sin(theta * harmonicA + phase)
                let fold = 1.0 + modulation * 0.28 * sin(theta * harmonicB - phase + layer * .pi)
                let radius = maxRadius * echoScale * rose * fold
                let local = SIMD2<Float>(cos(theta) * radius, sin(theta) * radius)
                append(rotate(local, by: echoRotation) + center, layer, 0.62 + 0.38 * rose, 1.0 + feedback * 0.6)
            }
        }
    }

    private func makeFourierKnotsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for curve in 0..<elementCount {
            let layer = Float(curve) / Float(max(1, elementCount - 1))
            let curvePhase = seedPhase + layer * .pi * 2.0
            let curveScale = maxRadius * (0.58 + 0.36 * sin(layer * .pi))
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let theta = t * .pi * 2.0
                let x = sin(theta * harmonicA + phase + curvePhase) +
                    0.45 * sin(theta * (harmonicB + 1.0) - phase + curvePhase)
                let y = cos(theta * harmonicB - phase + curvePhase) +
                    0.45 * cos(theta * (harmonicA + 2.0) + phase * 2.0)
                let breathing = 0.74 + modulation * 0.16 * sin(theta + phase + curvePhase)
                let local = SIMD2<Float>(x, y) * curveScale * breathing * 0.54
                append(
                    rotate(local, by: rotation + layer * 0.38) + center,
                    layer,
                    0.68 + 0.32 * abs(sin(theta + phase + curvePhase)),
                    0.78 + modulation * 0.38
                )
            }
        }
    }

    private func makeGuillocheVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for curve in 0..<elementCount {
            let layer = Float(curve) / Float(max(1, elementCount - 1))
            let curvePhase = layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let theta = t * .pi * 2.0
                let x = cos(theta * harmonicA + curvePhase + phase) * 0.55 +
                    cos(theta * harmonicB - phase) * modulation * 0.32
                let y = sin(theta * (harmonicA + 1.0) - curvePhase) * 0.55 +
                    sin(theta * (harmonicB - 1.0) + phase) * modulation * 0.32
                let local = SIMD2<Float>(x, y) * maxRadius * (0.68 + layer * 0.50)
                append(rotate(local, by: rotation + layer * 0.25) + center, layer, 0.78 + 0.22 * sin(theta + phase), 0.86)
            }
        }
    }

    private func makeGrowingNetworkVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let nodeCount = max(12, min(120, elementCount))
        let edgeSamples = max(4, samplesPerElement)
        let phaseUnit = phase / (.pi * 2.0)
        let networkRadius = maxRadius * (1.02 + depth * 0.24)
        var nodes: [SIMD2<Float>] = []
        nodes.reserveCapacity(nodeCount)

        for node in 0..<nodeCount {
            let id = Float(node)
            let radialSeed = fract(sin(seedPhase + id * 12.9898) * 43758.5453)
            let angleSeed = fract(sin(seedPhase * 1.37 + id * 78.233) * 24634.6345)
            let radius = sqrt(radialSeed) * networkRadius
            let angle = angleSeed * .pi * 2.0
            let drift = SIMD2<Float>(
                sin(phase + id * 0.73) * maxRadius * modulation * 0.018,
                cos(phase + id * 0.41) * maxRadius * modulation * 0.018
            )
            let local = SIMD2<Float>(
                cos(angle) * radius * (1.34 + depth * 0.18),
                sin(angle) * radius * (1.08 + depth * 0.12)
            ) + drift
            nodes.append(local)
        }

        for node in 0..<nodeCount {
            let layer = Float(node) / Float(max(1, nodeCount - 1))
            let birth = fract(layer * 0.77 + seedPhase * 0.017)
            let age = fract(phaseUnit - birth + 1.0)
            let nodePulse = smoothEnvelope(age, attack: 0.10, release: 0.88)
            if nodePulse > 0.02 {
                append(
                    rotate(nodes[node], by: rotation) + center,
                    layer,
                    0.45 + nodePulse * 0.65,
                    1.08 + nodePulse * 1.12
                )
            }

            let nextA = (node + Int(harmonicA)) % nodeCount
            let nextB = (node + Int(harmonicB)) % nodeCount
            let targets = [nextA, nextB]
            for (edgeIndex, target) in targets.enumerated() {
                let edgeBirth = fract(birth + Float(edgeIndex) * 0.13 + 0.09)
                let edgeAge = fract(phaseUnit - edgeBirth + 1.0)
                let growth = min(1.0, max(0.0, edgeAge / (0.34 + modulation * 0.22)))
                let edgeLife = smoothEnvelope(edgeAge, attack: 0.16, release: 0.94)
                if edgeLife <= 0.02 { continue }

                let from = nodes[node]
                let to = nodes[target]
                let samples = max(2, Int(Float(edgeSamples) * max(0.18, growth)))
                for sample in 0..<samples {
                    let t = Float(sample) / Float(max(1, edgeSamples - 1))
                    if t > growth { break }
                    let bend = sin(t * .pi) * maxRadius * modulation * 0.035
                    let normal = normalizeOrZero(SIMD2<Float>(-(to - from).y, (to - from).x))
                    let point = from + (to - from) * t + normal * bend
                    append(
                        rotate(point, by: rotation) + center,
                        layer,
                        0.35 + edgeLife * 0.66,
                        0.74 + edgeLife * 0.58
                    )
                }
            }
        }
    }

    private func makeInstancedGeometryVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let polygonSides = max(3, min(9, samplesPerElement))
        for instance in 0..<elementCount {
            let layer = Float(instance) / Float(max(1, elementCount - 1))
            let orbit = sqrt(layer) * maxRadius
            let angle = layer * .pi * 2.0 * harmonicA + seedPhase
            let wobble = modulation * maxRadius * 0.12 * sin(phase + layer * harmonicB)
            let instanceCenter = rotate(SIMD2<Float>(
                cos(angle + phase) * (orbit + wobble),
                sin(angle - phase) * (orbit * (0.72 + depth * 0.28))
            ), by: rotation) + center
            let size = maxRadius * (0.028 + 0.058 * (1.0 - layer) + modulation * 0.022)
            for vertex in 0..<polygonSides {
                let t = Float(vertex) / Float(polygonSides)
                let theta = t * .pi * 2.0 + phase + layer * .pi
                let local = SIMD2<Float>(cos(theta) * size, sin(theta) * size)
                append(instanceCenter + local, layer, 0.72 + 0.28 * sin(phase + layer), 1.1)
            }
        }
    }

    private func makeLaserRibbonsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for ribbon in 0..<elementCount {
            let layer = Float(ribbon) / Float(max(1, elementCount - 1))
            let lane = (layer - 0.5) * maxRadius * 1.72
            let ribbonPhase = seedPhase + layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let x = (t - 0.5) * maxRadius * 3.34
                let waveA = sin(t * .pi * 2.0 * harmonicA + phase + ribbonPhase)
                let waveB = cos(t * .pi * 2.0 * harmonicB - phase + ribbonPhase)
                let y = lane + (waveA * 0.65 + waveB * 0.35) * maxRadius * modulation * 0.30
                let sweep = SIMD2<Float>(
                    sin(phase + layer * .pi * 2.0) * maxRadius * modulation * 0.08,
                    cos(phase + t * .pi * 2.0) * maxRadius * modulation * 0.05
                )
                let local = SIMD2<Float>(x, y) + sweep
                append(
                    rotate(local, by: rotation + sin(phase + layer) * 0.08) + center,
                    layer,
                    0.70 + 0.30 * abs(waveA),
                    0.96 + modulation * 0.48
                )
            }
        }
    }

    private func makeMetaballVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for blob in 0..<elementCount {
            let layer = Float(blob) / Float(max(1, elementCount - 1))
            let orbitAngle = layer * .pi * 2.0 + seedPhase
            let blobCenter = rotate(SIMD2<Float>(
                cos(orbitAngle + phase) * maxRadius * 0.70,
                sin(orbitAngle * 2.0 - phase) * maxRadius * 0.52
            ), by: rotation) + center
            let baseRadius = maxRadius * (0.10 + 0.12 * (0.5 + 0.5 * sin(layer * harmonicA + phase)))
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(samplesPerElement)
                let theta = t * .pi * 2.0
                let merge = 1.0 + modulation * 0.34 * sin(theta * harmonicB + phase + layer * .pi)
                let local = SIMD2<Float>(cos(theta) * baseRadius * merge, sin(theta) * baseRadius * merge)
                append(blobCenter + local, layer, 0.66 + 0.34 * merge, 1.15)
            }
        }
    }

    private func makeMoireRingsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for ring in 0..<elementCount {
            let layer = Float(ring) / Float(max(1, elementCount - 1))
            let baseRadius = maxRadius * (0.08 + 1.24 * layer)
            let ringPhase = layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let theta = t * .pi * 2.0
                let beatA = sin(theta * harmonicA + phase + ringPhase)
                let beatB = cos(theta * harmonicB - phase + ringPhase)
                let ripple = (beatA * 0.55 + beatB * 0.45) * maxRadius * modulation * 0.046
                let radius = baseRadius + ripple + sin(ringPhase + phase) * maxRadius * 0.014
                let local = SIMD2<Float>(cos(theta) * radius, sin(theta) * radius)
                append(
                    rotate(local, by: rotation + sin(phase) * 0.04) + center,
                    layer,
                    0.62 + 0.38 * abs(beatA * beatB),
                    0.78 + modulation * 0.30
                )
            }
        }
    }

    private func makeNeonVortexVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        for arm in 0..<elementCount {
            let layer = Float(arm) / Float(max(1, elementCount - 1))
            let armPhase = seedPhase + layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let spiral = t * .pi * 2.0 * (1.2 + depth * 2.4) + armPhase + phase
                let wobble = sin(t * .pi * 2.0 * harmonicB - phase + armPhase) * modulation
                let radius = maxRadius * pow(t, 0.72) * (0.14 + 0.98 * (0.65 + 0.35 * sin(phase + armPhase)))
                let angle = spiral + wobble * 0.36 + sin(t * .pi * harmonicA + phase) * 0.18
                let local = SIMD2<Float>(cos(angle) * radius * 1.26, sin(angle) * radius)
                append(
                    rotate(local, by: rotation) + center,
                    layer,
                    0.66 + 0.34 * abs(wobble),
                    0.88 + (1.0 - t) * 0.72
                )
            }
        }
    }

    private func makeRadialOscilloscopeVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        for trace in 0..<elementCount {
            let layer = Float(trace) / Float(max(1, elementCount - 1))
            let tracePhase = seedPhase + layer * .pi * 2.0
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let theta = t * .pi * 2.0
                let signalA = sin(theta * harmonicA + phase + tracePhase)
                let signalB = cos(theta * harmonicB - phase + tracePhase)
                let radius = maxRadius * (0.20 + 1.06 * layer) +
                    maxRadius * modulation * 0.18 * (signalA * 0.65 + signalB * 0.35)
                let local = SIMD2<Float>(cos(theta) * radius * 1.38, sin(theta) * radius)
                append(
                    rotate(local, by: rotation + layer * 0.10) + center,
                    layer,
                    0.64 + 0.36 * abs(signalA),
                    0.86 + modulation * 0.34
                )
            }
        }
    }

    private func makeRainCurtainVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let dropCount = max(32, min(160, elementCount))
        let trailSamples = max(6, min(42, samplesPerElement))
        let width = maxRadius * (2.72 + depth * 0.34)
        let height = maxRadius * (1.88 + depth * 0.42)
        let phaseUnit = phase / (.pi * 2.0)
        let wind = maxRadius * modulation * 0.18

        for drop in 0..<dropCount {
            let layer = Float(drop) / Float(max(1, dropCount - 1))
            let id = seedPhase + Float(drop) * 19.191
            let xBase = (fract(sin(id) * 43758.5453) - 0.5) * width
            let offset = fract(cos(id * 0.73) * 14375.337)
            let laneSpeed = 1.0 + floor(fract(sin(id * 1.91) * 249.31) * 2.0)
            let fall = fract(offset + phaseUnit * laneSpeed)
            let yHead = (fall - 0.5) * height
            let xHead = xBase + sin(phase + layer * harmonicA) * wind
            let length = height * (0.055 + depth * 0.07 + fract(sin(id * 2.17) * 311.9) * 0.08)

            for sample in 0..<trailSamples {
                let t = Float(sample) / Float(max(1, trailSamples - 1))
                let localPulse = pow(1.0 - t, 1.35)
                let wrappedY = wrapCentered(yHead - length * t, span: height)
                let shear = sin(t * .pi + layer * harmonicB) * wind * 0.12
                let point = SIMD2<Float>(xHead + shear, wrappedY)
                append(
                    rotate(point, by: rotation) + center,
                    layer,
                    (0.30 + localPulse * 0.82) * LoopMath.lifetimeEnvelope(fract(wrappedY / height + 0.5)),
                    0.62 + localPulse * 1.18
                )
            }

            let splashPhase = max(0.0, 1.0 - abs(fall - 0.92) * 16.0)
            if splashPhase > 0.0 {
                let splashWidth = maxRadius * (0.018 + modulation * 0.035)
                let y = height * 0.46
                for spark in 0..<5 {
                    let sparkT = Float(spark) / 4.0 - 0.5
                    let point = SIMD2<Float>(xHead + sparkT * splashWidth, y + abs(sparkT) * splashWidth * 0.25)
                    append(
                        rotate(point, by: rotation) + center,
                        layer,
                        0.40 + splashPhase * 0.70,
                        0.78 + splashPhase * 0.74
                    )
                }
            }
        }
    }

    private func makeTruchetFlowVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        rotation: Float
    ) {
        let columns = max(8, min(48, elementCount))
        let rows = max(6, min(36, samplesPerElement))
        let tileWidth = maxRadius * 3.02 / Float(columns)
        let tileHeight = maxRadius * 2.20 / Float(rows)
        let samplesPerArc = 16
        for column in 0..<columns {
            let xLayer = Float(column) / Float(max(1, columns - 1))
            for row in 0..<rows {
                let yLayer = Float(row) / Float(max(1, rows - 1))
                    let selector = sin(Float(column) * harmonicA + Float(row) * harmonicB + seedPhase + phase)
                    let baseCenter = SIMD2<Float>(
                    (xLayer - 0.5) * maxRadius * 3.02,
                    (yLayer - 0.5) * maxRadius * 2.20
                )
                for sample in 0..<samplesPerArc {
                    let t = Float(sample) / Float(max(1, samplesPerArc - 1))
                    let theta = t * .pi * 0.5
                    let cornerOffset = selector >= 0
                        ? SIMD2<Float>(-tileWidth * 0.5, -tileHeight * 0.5)
                        : SIMD2<Float>(tileWidth * 0.5, -tileHeight * 0.5)
                    let arc = selector >= 0
                        ? SIMD2<Float>(cos(theta) * tileWidth * 0.5, sin(theta) * tileHeight * 0.5)
                        : SIMD2<Float>(-cos(theta) * tileWidth * 0.5, sin(theta) * tileHeight * 0.5)
                    let flow = SIMD2<Float>(
                        sin(phase + xLayer * .pi * 2.0) * tileWidth * modulation * 0.18,
                        cos(phase - yLayer * .pi * 2.0) * tileHeight * modulation * 0.18
                    )
                    let local = baseCenter + cornerOffset + arc + flow
                    append(
                        rotate(local, by: rotation) + center,
                        (xLayer + yLayer) * 0.5,
                        0.70 + 0.30 * abs(selector),
                        0.92
                    )
                }
            }
        }
    }

    private func makeLabyrinthTraceVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let columns = max(12, min(44, elementCount))
        let rows = max(8, min(32, Int(Float(elementCount) * 0.68)))
        let width = maxRadius * 3.18
        let height = maxRadius * 2.20
        let cellWidth = width / Float(columns)
        let cellHeight = height / Float(rows)
        let pathCount = max(8, min(34, Int(Float(elementCount) * (0.58 + depth * 0.18))))
        let stepCount = max(14, min(56, samplesPerElement))
        let samplesPerStep = 5
        let rotationPhase = rotation / (.pi * 2.0)

        func mazeHash(_ x: Int, _ y: Int, _ step: Int, _ path: Int) -> Float {
            fract(sin(Float(x * 37 + y * 67 + step * 97 + path * 131) + seedPhase) * 43758.5453)
        }

        func cellCenter(_ x: Int, _ y: Int) -> SIMD2<Float> {
            SIMD2<Float>(
                (Float(x) + 0.5) * cellWidth - width * 0.5,
                (Float(y) + 0.5) * cellHeight - height * 0.5
            )
        }

        for path in 0..<pathCount {
            let layer = Float(path) / Float(max(1, pathCount - 1))
            var x = Int(floor(mazeHash(path, 0, 0, path) * Float(columns)))
            var y = Int(floor(mazeHash(0, path, 1, path) * Float(rows)))
            let localPhase = fract(phase / (.pi * 2.0) + layer * 0.37 + rotationPhase * 0.25)

            for step in 0..<stepCount {
                let directionSelector = mazeHash(x, y, step, path)
                let turnBias = sin(phase + Float(step) * 0.37 + layer * harmonicB)
                let direction = Int(floor(fract(directionSelector + turnBias * modulation * 0.18) * 4.0))
                let nextX: Int
                let nextY: Int
                switch direction {
                case 0:
                    nextX = min(columns - 1, x + 1)
                    nextY = y
                case 1:
                    nextX = x
                    nextY = min(rows - 1, y + 1)
                case 2:
                    nextX = max(0, x - 1)
                    nextY = y
                default:
                    nextX = x
                    nextY = max(0, y - 1)
                }

                let stepLayer = Float(step) / Float(max(1, stepCount - 1))
                let chase = max(0.0, 1.0 - abs(fract(localPhase - stepLayer + 1.0) - 0.5) * 2.8)
                let basePulse = 0.38 + pow(chase, 1.8) * 0.82
                let start = cellCenter(x, y)
                let end = cellCenter(nextX, nextY)

                for sample in 0..<samplesPerStep {
                    let t = Float(sample) / Float(max(1, samplesPerStep - 1))
                    let jitter = SIMD2<Float>(
                        sin(phase + Float(step) * harmonicA * 0.11 + layer * 5.1) * cellWidth,
                        cos(phase + Float(step) * harmonicB * 0.09 + layer * 4.7) * cellHeight
                    ) * modulation * 0.10
                    let point = start + (end - start) * t + jitter
                    append(point + center, fract(layer + stepLayer * 0.25), basePulse, 0.88 + chase * 1.10)
                }

                x = nextX
                y = nextY
            }
        }
    }

    private func makeLuminousStringsVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        let stringCount = max(8, min(30, elementCount))
        let sampleCount = max(140, min(900, samplesPerElement))
        let xSpan = maxRadius * 1.62
        let ySpan = maxRadius * 1.12
        let rotationPhase = rotation / (.pi * 2.0)

        for string in 0..<stringCount {
            let layer = Float(string) / Float(max(1, stringCount - 1))
            let offset = seedPhase + layer * .pi * 2.0
            let travelPhase = phase + sin(phase) * 0.28 * fract(layer * 9.73)
            let swimPhase = travelPhase + rotationPhase
            let bodyScale = 0.68 + depth * 0.42 + fract(sin(layer * 41.3 + seedPhase) * 91.7) * 0.20

            for sample in 0..<sampleCount {
                let t = Float(sample) / Float(max(1, sampleCount - 1))
                let along = (t - 0.5) * 2.0
                let envelope = pow(max(0.0, 1.0 - abs(along)), 0.38)
                let waveA = sin(along * .pi * harmonicA + swimPhase + offset)
                let waveB = sin(along * .pi * harmonicB - travelPhase * 2.0 - rotationPhase * 1.23 + offset * 0.7)
                let driftX = sin(swimPhase + offset * 0.51) * xSpan * 0.24
                let driftY = cos(travelPhase + rotationPhase * 0.87 + offset * 0.43) * ySpan * 0.22
                let x = along * xSpan * bodyScale * (0.44 + modulation * 0.20) +
                    waveB * xSpan * modulation * 0.12 +
                    driftX
                let y = waveA * ySpan * (0.20 + modulation * 0.22) +
                    sin(along * .pi * 2.0 + travelPhase * 2.0 + rotationPhase * 1.8 + offset) * ySpan * 0.12 +
                    driftY
                let braid = sin(t * .pi * 2.0 * 7.0 + phase * 2.0 + layer * .pi)
                let point = SIMD2<Float>(x, y + braid * ySpan * 0.018 * modulation)
                let pulse = 0.54 + envelope * 0.46 + abs(braid) * 0.16
                append(point + center, fract(layer + t * 0.18), pulse, 0.74 + envelope * 0.92)
            }
        }
    }

    private func makePenroseVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        seedPhase: Float,
        harmonicA: Float,
        modulation: Float,
        rotation: Float
    ) {
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))
        for index in 0..<elementCount {
            let layer = Float(index) / Float(max(1, elementCount - 1))
            let radius = sqrt(layer) * maxRadius
            let angle = Float(index) * goldenAngle + seedPhase
            let a = rotate(SIMD2<Float>(cos(angle) * radius, sin(angle) * radius), by: rotation) + center
            let edgeAngle = angle + Float(Int(harmonicA) % 5) * .pi / 5.0 + phase
            let edgeLength = maxRadius * (0.10 + 0.08 * sin(phase + layer * .pi * 2.0) * modulation + 0.08)
            let b = a + SIMD2<Float>(cos(edgeAngle) * edgeLength, sin(edgeAngle) * edgeLength)
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                append(a + (b - a) * t, layer, 0.72 + 0.28 * sin(phase + layer * .pi), 0.92)
            }
        }
    }

    private func makeWaveTerrainVertices(
        append: (SIMD2<Float>, Float, Float, Float) -> Void,
        elementCount: Int,
        samplesPerElement: Int,
        center: SIMD2<Float>,
        maxRadius: Float,
        phase: Float,
        harmonicA: Float,
        harmonicB: Float,
        modulation: Float,
        depth: Float,
        rotation: Float
    ) {
        for row in 0..<elementCount {
            let layer = Float(row) / Float(max(1, elementCount - 1))
            let yBase = (layer - 0.5) * maxRadius * 2.64
            for sample in 0..<samplesPerElement {
                let t = Float(sample) / Float(max(1, samplesPerElement - 1))
                let x = (t - 0.5) * maxRadius * 3.82
                let waveA = sin(t * .pi * 2.0 * harmonicA + phase + layer * .pi)
                let waveB = sin(t * .pi * 2.0 * harmonicB - phase + layer * .pi * 2.0)
                let y = yBase + (waveA * 0.55 + waveB * 0.45) * maxRadius * modulation * 0.16
                let perspective = 0.90 + depth * 0.16 * layer
                let local = SIMD2<Float>(x * perspective, y * perspective)
                append(rotate(local, by: rotation) + center, layer, 0.66 + 0.34 * abs(waveA), 0.9 + depth * 0.5)
            }
        }
    }

    private func smoothEnvelope(_ age: Float, attack: Float, release: Float) -> Float {
        if age < attack {
            return max(0.0, min(1.0, age / max(0.001, attack)))
        }
        if age > release {
            return max(0.0, min(1.0, (1.0 - age) / max(0.001, 1.0 - release)))
        }
        return 1.0
    }

    private func normalizeOrZero(_ vector: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(vector)
        guard length > 0.0001 else { return .zero }
        return vector / length
    }

    private func wrapCentered(_ value: Float, span: Float) -> Float {
        let normalized = fract((value / max(0.001, span)) + 0.5)
        return (normalized - 0.5) * span
    }

    private func rotate(_ point: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD2<Float>(
            point.x * c - point.y * s,
            point.x * s + point.y * c
        )
    }

    private func normalizedPosition(_ position: SIMD2<Float>, width: Float, height: Float) -> SIMD2<Float> {
        SIMD2<Float>(
            (position.x / width) * 2.0 - 1.0,
            1.0 - (position.y / height) * 2.0
        )
    }

    private func hsvToRGB(hueDegrees: Float, saturation: Float, value: Float) -> SIMD3<Float> {
        let h = (hueDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0) / 60.0
        let c = value * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))

        let rgb: SIMD3<Float>
        switch h {
        case 0..<1:
            rgb = SIMD3<Float>(c, x, 0)
        case 1..<2:
            rgb = SIMD3<Float>(x, c, 0)
        case 2..<3:
            rgb = SIMD3<Float>(0, c, x)
        case 3..<4:
            rgb = SIMD3<Float>(0, x, c)
        case 4..<5:
            rgb = SIMD3<Float>(x, 0, c)
        default:
            rgb = SIMD3<Float>(c, 0, x)
        }

        let m = value - c
        return rgb + SIMD3<Float>(repeating: m)
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func fract(_ value: Float) -> Float {
        value - floor(value)
    }
}

extension GenerativeFrameRenderer {
    func sampleVertices(
        parameters: RenderParameters, seed: UInt64, frameIndex: Int,
        clock: RenderClock, drawableSize: CGSize
    ) -> [FieldLinesVertex] {
        switch parameters {
        case .fieldLines(let p):
            return fieldLinesRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .orbital(let p):
            return orbitalRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .softVolumetric(let p):
            return softVolumetricRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .gridCity(let p):
            return gridCityRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .interferenceField(let p):
            return interferenceFieldRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .periodicNoise(let p):
            return periodicNoiseRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .cyclicAutomata(let p):
            return cyclicAutomataRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .agentSwarm(let p):
            return agentSwarmRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .kaleidoscope(let p):
            return kaleidoscopeRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .voronoiFlow(let p):
            return voronoiFlowRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .reactionDiffusion(let p):
            return reactionDiffusionRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .plasmaField(let p):
            return plasmaFieldRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .harmonicTunnel(let p):
            return harmonicTunnelRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .lissajousWeave(let p):
            return lissajousWeaveRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .phyllotaxisBloom(let p):
            return phyllotaxisBloomRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .hexPulseLattice(let p):
            return hexPulseLatticeRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .superformulaMorph(let p):
            return superformulaMorphRenderer.makeVertices(parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        case .auroraCurtain(let p), .bloomingCircuits(let p), .cellularBloom(let p),
             .chladniPlate(let p), .circuitTracer(let p), .cityLightsBokeh(let p),
             .closedFlowParticles(let p), .constellationDrift(let p), .crystalLattice(let p),
             .dataMesh(let p), .digitalSand(let p), .electricStorm(let p), .sdfTunnel(let p),
             .feedbackSynth(let p), .fireworksShow(let p), .fluidNodes(let p), .fourierKnots(let p),
             .guillocheRose(let p), .growingNetwork(let p), .instancedGeometry(let p),
             .inkInWater(let p), .laserRibbons(let p), .luminousBubbles(let p),
             .metaballField(let p), .moireRings(let p), .neonVortex(let p),
             .origamiTessellation(let p), .particleFountain(let p), .penroseTiling(let p),
             .pulseNetwork(let p), .radialOscilloscope(let p), .rainCurtain(let p),
             .ribbonCascade(let p), .sakuraDrift(let p), .scanlineTopography(let p),
             .schoolingSwarm(let p), .snowfallDepth(let p), .solarCorona(let p),
             .truchetFlow(let p), .underwaterCaustics(let p), .volumetricNebula(let p),
             .waveTerrain(let p), .wireframeMorph(let p), .proceduralPattern(_, let p):
            return proceduralPatternRenderer.makeVertices(family: parameters.rendererFamily,
                parameters: p, seed: seed, frameIndex: frameIndex, clock: clock, drawableSize: drawableSize)
        }
    }
}

enum RendererError: Error {
    case missingShaderFunction
    case samplerCreationFailed
}
