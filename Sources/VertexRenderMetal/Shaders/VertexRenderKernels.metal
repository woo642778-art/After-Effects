#include <metal_stdlib>
using namespace metal;

struct VertexSolidParameters {
    float4 color;
};

struct VertexLayerParameters {
    uint4 dimensions;
    float4 positionAnchor;
    float4 scaleRotationOpacity;
    float4 effects;
};

struct VertexCompositeParameters {
    uint4 dimensionsAndMode;
};

struct VertexAdjustmentParameters {
    uint4 dimensions;
    float4 effectsAndMix;
};

struct VertexMaskParameters {
    uint4 dimensionsAndCounts;
};

struct VertexMaskHeader {
    uint4 metadata;
    float4 effects;
};

struct VertexMaskSegment {
    float4 endpoints;
};

struct VertexMatteParameters {
    uint4 dimensionsAndMode;
};

constant sampler vertexLinearSampler(
    coord::normalized,
    address::clamp_to_zero,
    filter::linear
);

inline float3 vertexStraightRGB(float4 premultiplied) {
    return premultiplied.a > 0.000001
        ? premultiplied.rgb / premultiplied.a
        : float3(0.0);
}

inline float3 vertexApplyEffects(
    float3 color,
    float exposure,
    float saturation,
    float invert
) {
    float3 result = color * exp2(exposure);
    const float luminance = dot(result, float3(0.2126, 0.7152, 0.0722));
    result = mix(float3(luminance), result, max(saturation, 0.0));
    if (invert > 0.5) {
        result = 1.0 - result;
    }
    return clamp(result, 0.0, 1.0);
}

inline float vertexSegmentDistance(float2 point, float2 a, float2 b) {
    const float2 direction = b - a;
    const float lengthSquared = dot(direction, direction);
    if (lengthSquared <= 0.000001) {
        return distance(point, a);
    }
    const float t = clamp(dot(point - a, direction) / lengthSquared, 0.0, 1.0);
    return distance(point, a + direction * t);
}

inline bool vertexPointInsideMask(
    float2 point,
    device const VertexMaskSegment* segments,
    uint segmentOffset,
    uint segmentCount,
    float2 dimensions,
    thread float& minimumDistance
) {
    bool inside = false;
    minimumDistance = INFINITY;
    for (uint segmentIndex = 0; segmentIndex < segmentCount; ++segmentIndex) {
        const VertexMaskSegment segment = segments[segmentOffset + segmentIndex];
        const float2 a = segment.endpoints.xy * dimensions;
        const float2 b = segment.endpoints.zw * dimensions;
        minimumDistance = min(minimumDistance, vertexSegmentDistance(point, a, b));

        const bool crossesY = (a.y > point.y) != (b.y > point.y);
        if (crossesY) {
            const float denominator = b.y - a.y;
            const float intersectionX = a.x + (point.y - a.y) * (b.x - a.x) / denominator;
            if (point.x < intersectionX) {
                inside = !inside;
            }
        }
    }
    return inside;
}

kernel void vertexSolidKernel(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    constant VertexSolidParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    if (position.x >= outputTexture.get_width() || position.y >= outputTexture.get_height()) {
        return;
    }
    const float alpha = clamp(parameters.color.a, 0.0, 1.0);
    outputTexture.write(float4(clamp(parameters.color.rgb, 0.0, 1.0) * alpha, alpha), position);
}

kernel void vertexLayerKernel(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant VertexLayerParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint outputWidth = parameters.dimensions.z;
    const uint outputHeight = parameters.dimensions.w;
    if (position.x >= outputWidth || position.y >= outputHeight) {
        return;
    }

    const float2 outputUV = (float2(position) + 0.5) / float2(outputWidth, outputHeight);
    const float2 layerPosition = parameters.positionAnchor.xy;
    const float2 anchor = parameters.positionAnchor.zw;
    const float2 scale = max(parameters.scaleRotationOpacity.xy, float2(0.000001));
    const float angle = -parameters.scaleRotationOpacity.z;
    const float2 delta = outputUV - layerPosition;
    const float cosine = cos(angle);
    const float sine = sin(angle);
    const float2 rotated = float2(
        cosine * delta.x - sine * delta.y,
        sine * delta.x + cosine * delta.y
    );
    const float2 sourceUV = anchor + rotated / scale;

    const float4 sampledPremultiplied = inputTexture.sample(vertexLinearSampler, sourceUV);
    const float sourceAlpha = clamp(sampledPremultiplied.a, 0.0, 1.0);
    float3 straight = vertexStraightRGB(sampledPremultiplied);
    straight = vertexApplyEffects(
        straight,
        parameters.effects.x,
        parameters.effects.y,
        parameters.effects.z
    );
    const float alpha = sourceAlpha * clamp(parameters.scaleRotationOpacity.w, 0.0, 1.0);
    outputTexture.write(float4(straight * alpha, alpha), position);
}

kernel void vertexMaskKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant VertexMaskParameters& parameters [[buffer(0)]],
    device const VertexMaskHeader* headers [[buffer(1)]],
    device const VertexMaskSegment* segments [[buffer(2)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint width = parameters.dimensionsAndCounts.x;
    const uint height = parameters.dimensionsAndCounts.y;
    const uint maskCount = parameters.dimensionsAndCounts.z;
    if (position.x >= width || position.y >= height) {
        return;
    }

    const float2 dimensions = float2(width, height);
    const float2 point = float2(position) + 0.5;
    float accumulatedCoverage = 1.0;
    bool hasParticipatingMask = false;

    for (uint maskIndex = 0; maskIndex < maskCount; ++maskIndex) {
        const VertexMaskHeader header = headers[maskIndex];
        const uint segmentOffset = header.metadata.x;
        const uint segmentCount = header.metadata.y;
        const uint mode = header.metadata.z;
        const uint flags = header.metadata.w;
        const bool enabled = (flags & 1u) != 0u;
        const bool inverted = (flags & 2u) != 0u;
        if (!enabled || mode == 3u) {
            continue;
        }

        float minimumDistance = INFINITY;
        const bool inside = vertexPointInsideMask(
            point,
            segments,
            segmentOffset,
            segmentCount,
            dimensions,
            minimumDistance
        );
        const float signedDistance = inside ? -minimumDistance : minimumDistance;
        const float opacity = clamp(header.effects.x, 0.0, 1.0);
        const float feather = max(header.effects.y, 0.0);
        const float expansion = header.effects.z;
        float maskCoverage;
        if (feather <= 0.0001) {
            maskCoverage = signedDistance <= expansion ? 1.0 : 0.0;
        } else {
            const float halfFeather = feather * 0.5;
            maskCoverage = 1.0 - smoothstep(
                expansion - halfFeather,
                expansion + halfFeather,
                signedDistance
            );
        }
        if (inverted) {
            maskCoverage = 1.0 - maskCoverage;
        }
        maskCoverage = clamp(maskCoverage * opacity, 0.0, 1.0);

        if (!hasParticipatingMask) {
            if (mode == 1u) {
                accumulatedCoverage = 1.0 - maskCoverage;
            } else {
                accumulatedCoverage = maskCoverage;
            }
            hasParticipatingMask = true;
            continue;
        }

        switch (mode) {
            case 0u:
                accumulatedCoverage = max(accumulatedCoverage, maskCoverage);
                break;
            case 1u:
                accumulatedCoverage *= (1.0 - maskCoverage);
                break;
            case 2u:
                accumulatedCoverage = min(accumulatedCoverage, maskCoverage);
                break;
            default:
                break;
        }
    }

    if (!hasParticipatingMask) {
        accumulatedCoverage = 1.0;
    }
    const float coverage = clamp(accumulatedCoverage, 0.0, 1.0);
    const float4 source = inputTexture.read(position);
    outputTexture.write(source * coverage, position);
}

kernel void vertexMatteKernel(
    texture2d<float, access::sample> sourceTexture [[texture(0)]],
    texture2d<float, access::sample> matteTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant VertexMatteParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint width = parameters.dimensionsAndMode.x;
    const uint height = parameters.dimensionsAndMode.y;
    const uint mode = parameters.dimensionsAndMode.z;
    if (position.x >= width || position.y >= height) {
        return;
    }

    const float2 uv = (float2(position) + 0.5) / float2(width, height);
    const float4 source = sourceTexture.sample(vertexLinearSampler, uv);
    const float4 matte = matteTexture.sample(vertexLinearSampler, uv);
    float coverage;
    if (mode == 2u || mode == 3u) {
        const float matteAlpha = clamp(matte.a, 0.0, 1.0);
        coverage = dot(vertexStraightRGB(matte), float3(0.2126, 0.7152, 0.0722)) * matteAlpha;
    } else {
        coverage = clamp(matte.a, 0.0, 1.0);
    }
    if (mode == 1u || mode == 3u) {
        coverage = 1.0 - coverage;
    }
    outputTexture.write(source * clamp(coverage, 0.0, 1.0), position);
}

inline float3 vertexBlend(float3 backdrop, float3 source, uint mode) {
    switch (mode) {
        case 1:
            return clamp(backdrop + source, 0.0, 1.0);
        case 2:
            return backdrop * source;
        case 3:
            return 1.0 - (1.0 - backdrop) * (1.0 - source);
        default:
            return source;
    }
}

kernel void vertexCompositeKernel(
    texture2d<float, access::sample> backdropTexture [[texture(0)]],
    texture2d<float, access::sample> sourceTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant VertexCompositeParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint outputWidth = parameters.dimensionsAndMode.x;
    const uint outputHeight = parameters.dimensionsAndMode.y;
    if (position.x >= outputWidth || position.y >= outputHeight) {
        return;
    }

    const float2 uv = (float2(position) + 0.5) / float2(outputWidth, outputHeight);
    const float4 backdropPremul = backdropTexture.sample(vertexLinearSampler, uv);
    const float4 sourcePremul = sourceTexture.sample(vertexLinearSampler, uv);
    const float ab = clamp(backdropPremul.a, 0.0, 1.0);
    const float as = clamp(sourcePremul.a, 0.0, 1.0);
    const float3 cb = vertexStraightRGB(backdropPremul);
    const float3 cs = vertexStraightRGB(sourcePremul);
    const float3 blended = vertexBlend(cb, cs, parameters.dimensionsAndMode.z);
    const float ao = as + ab * (1.0 - as);
    const float3 co =
        as * (1.0 - ab) * cs
        + as * ab * blended
        + ab * (1.0 - as) * cb;
    outputTexture.write(float4(clamp(co, 0.0, 1.0), clamp(ao, 0.0, 1.0)), position);
}

kernel void vertexAdjustmentKernel(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant VertexAdjustmentParameters& parameters [[buffer(0)]],
    uint2 position [[thread_position_in_grid]]
) {
    const uint outputWidth = parameters.dimensions.x;
    const uint outputHeight = parameters.dimensions.y;
    if (position.x >= outputWidth || position.y >= outputHeight) {
        return;
    }

    const float2 uv = (float2(position) + 0.5) / float2(outputWidth, outputHeight);
    const float4 original = inputTexture.sample(vertexLinearSampler, uv);
    const float alpha = clamp(original.a, 0.0, 1.0);
    const float3 adjustedStraight = vertexApplyEffects(
        vertexStraightRGB(original),
        parameters.effectsAndMix.x,
        parameters.effectsAndMix.y,
        parameters.effectsAndMix.z
    );
    const float4 adjusted = float4(adjustedStraight * alpha, alpha);
    outputTexture.write(
        clamp(mix(original, adjusted, clamp(parameters.effectsAndMix.w, 0.0, 1.0)), 0.0, 1.0),
        position
    );
}
