import Metal

protocol RendererDiagnostics: AnyObject {
    var renderingError: Error? { get set }
}

enum RenderEncodingError: Error {
    case textureCreationFailed
    case bufferCreationFailed
    case encoderCreationFailed
    case commandBufferCreationFailed
}

enum GenerativeRenderStyle {
    static let backgroundColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
}

func encodePointVertices(
    _ vertices: [FieldLinesVertex],
    device: MTLDevice,
    pipeline: MTLRenderPipelineState,
    commandBuffer: MTLCommandBuffer,
    descriptor: MTLRenderPassDescriptor
) throws {
    descriptor.colorAttachments[0].clearColor = GenerativeRenderStyle.backgroundColor
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
        throw RenderEncodingError.encoderCreationFailed
    }
    defer { encoder.endEncoding() }
    guard !vertices.isEmpty else { return }
    guard let buffer = device.makeBuffer(
        bytes: vertices,
        length: MemoryLayout<FieldLinesVertex>.stride * vertices.count,
        options: [.storageModeShared]
    ) else {
        throw RenderEncodingError.bufferCreationFailed
    }
    encoder.setRenderPipelineState(pipeline)
    encoder.setVertexBuffer(buffer, offset: 0, index: 0)
    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: vertices.count)
}
