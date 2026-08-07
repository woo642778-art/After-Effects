#if canImport(Metal)
@preconcurrency import Metal
import simd
import VertexRender

internal struct MetalSolidParameters {
    var color: SIMD4<Float>
}

internal struct MetalLayerParameters {
    var dimensions: SIMD4<UInt32>
    var positionAnchor: SIMD4<Float>
    var scaleRotationOpacity: SIMD4<Float>
    var effects: SIMD4<Float>
}

internal struct MetalCompositeParameters {
    var dimensionsAndMode: SIMD4<UInt32>
}

internal struct MetalAdjustmentParameters {
    var dimensions: SIMD4<UInt32>
    var effectsAndMix: SIMD4<Float>
}

internal struct MetalMaskParameters {
    var dimensionsAndCounts: SIMD4<UInt32>
}

internal struct MetalMaskHeader {
    var metadata: SIMD4<UInt32>
    var effects: SIMD4<Float>
}

internal struct MetalMaskSegment {
    var endpoints: SIMD4<Float>
}

internal struct MetalMatteParameters {
    var dimensionsAndMode: SIMD4<UInt32>
}

internal extension RenderBlendMode {
    var metalValue: UInt32 {
        switch self {
        case .normal: 0
        case .add: 1
        case .multiply: 2
        case .screen: 3
        }
    }
}

internal extension RenderMaskMode {
    var metalValue: UInt32 { rawValue }
}

internal extension RenderTrackMatteMode {
    var metalValue: UInt32 { rawValue }
}
#endif
