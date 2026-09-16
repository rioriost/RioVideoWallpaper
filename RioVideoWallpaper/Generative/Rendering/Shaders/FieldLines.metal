#include <metal_stdlib>
using namespace metal;

struct FieldLinesVertex {
    float2 position;
    float4 color;
    float pointSize;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex VertexOut fieldLinesVertex(
    uint vertexID [[vertex_id]],
    const device FieldLinesVertex *vertices [[buffer(0)]]
) {
    FieldLinesVertex input = vertices[vertexID];
    VertexOut out;
    out.position = float4(input.position, 0.0, 1.0);
    out.color = input.color;
    out.pointSize = input.pointSize;
    return out;
}

fragment float4 fieldLinesFragment(
    VertexOut input [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    float2 centered = pointCoord * 2.0 - 1.0;
    float falloff = exp(-dot(centered, centered) * 2.8);
    return float4(input.color.rgb, input.color.a * falloff);
}

struct FullscreenOut {
    float4 position [[position]];
    float2 uv;
};

vertex FullscreenOut fieldLinesFullscreenVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    FullscreenOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

fragment float4 fieldLinesFadeFragment(
    FullscreenOut input [[stage_in]],
    texture2d<float> previousTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]],
    constant float &fadeFactor [[buffer(0)]]
) {
    return float4(previousTexture.sample(textureSampler, input.uv).rgb * fadeFactor, 1.0);
}

fragment float4 fieldLinesCopyFragment(
    FullscreenOut input [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    return float4(texture.sample(textureSampler, input.uv).rgb, 1.0);
}
