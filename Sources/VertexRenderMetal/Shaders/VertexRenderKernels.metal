#include <metal_stdlib>
using namespace metal;

struct VertexRenderParameters {
    uint4 dimensions;
    float scale;
    float translationX;
    float translationY;
    float exposure;
    float saturation;
    float opacity;
    uint invert;
    uint padding;
};

kernel void vertexRenderKernel(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant VertexRenderParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint outputWidth = parameters.dimensions.z;
    const uint outputHeight = parameters.dimensions.w;
    if (position.x >= outputWidth || position.y >= outputHeight) {
        return;
    }

    constexpr sampler linearSampler(
        coord::normalized,
        address::clamp_to_zero,
        filter::linear
    );

    const float2 outputSize = float2(outputWidth, outputHeight);
    const float2 outputUV = (float2(position) + 0.5) / outputSize;
    const float2 translation = float2(parameters.translationX, parameters.translationY);
    const float2 sourceUV = ((outputUV - 0.5 - translation) / max(parameters.scale, 0.0001)) + 0.5;

    float4 color = inputTexture.sample(linearSampler, sourceUV);
    color.rgb *= exp2(parameters.exposure);

    const float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(float3(luminance), color.rgb, clamp(parameters.saturation, 0.0, 4.0));

    if (parameters.invert != 0) {
        color.rgb = 1.0 - color.rgb;
    }

    color *= clamp(parameters.opacity, 0.0, 1.0);
    outputTexture.write(clamp(color, 0.0, 1.0), position);
}
