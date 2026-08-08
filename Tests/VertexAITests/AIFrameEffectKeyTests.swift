import Testing
import VertexCore
@testable import VertexAI

private func key(
    time: RationalTime = RationalTime(value: 1, timescale: 30),
    modelDigest: String = String(repeating: "a", count: 64),
    parameterDigest: String = String(repeating: "b", count: 64),
    quality: String = "balanced",
    width: Int = 640,
    height: Int = 360,
    orientation: String = "up",
    color: String = "rec709"
) throws -> AIFrameEffectKey {
    try AIFrameEffectKey(
        sourceFingerprint: "source-fingerprint",
        exactTime: time,
        modelID: "depth-anything-v2-small-f16",
        modelDigest: modelDigest,
        effectType: "depthMap",
        algorithmVersion: 1,
        parameterDigest: parameterDigest,
        qualityTier: quality,
        width: width,
        height: height,
        orientationDigest: orientation,
        colorDigest: color
    )
}

@Test("Frame effect key digest is stable for identical semantic inputs")
func frameKeyDigestIsStable() throws {
    #expect(try key().digest == key().digest)
}

@Test("Every output-affecting field invalidates frame effect cache identity")
func frameKeyChangesForEverySemanticInput() throws {
    let baseline = try key().digest
    let variants = try [
        key(time: RationalTime(value: 2, timescale: 30)),
        key(modelDigest: String(repeating: "c", count: 64)),
        key(parameterDigest: String(repeating: "d", count: 64)),
        key(quality: "quality"),
        key(width: 1280),
        key(height: 720),
        key(orientation: "left"),
        key(color: "display-p3")
    ]
    #expect(variants.allSatisfy { $0.digest != baseline })
    #expect(Set(variants.map(\.digest)).count == variants.count)
}

@Test("Frame effect key rejects invalid dimensions and empty identity fields")
func frameKeyValidatesInputs() throws {
    #expect(throws: AIError.self) {
        _ = try AIFrameEffectKey(
            sourceFingerprint: "", exactTime: .zero, modelID: "m", modelDigest: "d",
            effectType: "depthMap", algorithmVersion: 1, parameterDigest: "p",
            qualityTier: "balanced", width: 0, height: 1,
            orientationDigest: "up", colorDigest: "rec709"
        )
    }
}

@Test("AI frame priority has explicit deterministic ordering")
func framePriorityOrderingIsExplicit() {
    #expect(AIFramePriority.background < .workArea)
    #expect(AIFramePriority.workArea < .playbackNeighbor)
    #expect(AIFramePriority.playbackNeighbor < .currentFrame)
}
