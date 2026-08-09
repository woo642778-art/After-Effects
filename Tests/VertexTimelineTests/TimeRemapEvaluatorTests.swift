import Testing
import VertexCore
import VertexProject
@testable import VertexTimeline

@Test("Linear Time Remap resolves an exact midpoint")
func exactLinearTimeRemapMidpoint() throws {
    let mapping = try ProjectTimeRemap(keyframes: [
        ProjectTimeRemapKeyframe(compositionTime: .zero, sourceTime: RationalTime(value: 2, timescale: 1)),
        ProjectTimeRemapKeyframe(compositionTime: RationalTime(value: 10, timescale: 1), sourceTime: RationalTime(value: 22, timescale: 1))
    ]).validated()

    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: RationalTime(value: 5, timescale: 1)) == RationalTime(value: 12, timescale: 1))
}

@Test("Reverse Time Remap preserves exact 29.97 frame positions")
func reverse2997IsExact() throws {
    let frameRate = RationalTime(value: 30_000, timescale: 1_001)
    let tenSeconds = RationalTime(value: 300_000, timescale: 30_000)
    let mapping = try ProjectTimeRemap.reverse(
        compositionDuration: tenSeconds,
        sourceStart: .zero,
        sourceDuration: tenSeconds
    )
    let oneFrame = RationalTime(value: Int64(frameRate.timescale), timescale: Int32(frameRate.value))
    let expected = try tenSeconds.subtracting(oneFrame)

    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: oneFrame) == expected)
}

@Test("Freeze returns the same source time across composition time")
func freezeTimeRemapIsConstant() throws {
    let source = RationalTime(value: 77, timescale: 30)
    let mapping = try ProjectTimeRemap.freeze(
        compositionDuration: RationalTime(value: 10, timescale: 1),
        sourceTime: source
    )
    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: .zero) == source)
    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: RationalTime(value: 9, timescale: 1)) == source)
}

@Test("Hold segment keeps previous source time until exact key boundary")
func holdTimeRemapBoundary() throws {
    let mapping = try ProjectTimeRemap(keyframes: [
        ProjectTimeRemapKeyframe(compositionTime: .zero, sourceTime: RationalTime(value: 3, timescale: 1), interpolation: .hold),
        ProjectTimeRemapKeyframe(compositionTime: RationalTime(value: 2, timescale: 1), sourceTime: RationalTime(value: 9, timescale: 1))
    ]).validated()
    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: RationalTime(value: 1999, timescale: 1000)) == RationalTime(value: 3, timescale: 1))
    #expect(try TimeRemapEvaluator().sourceTime(mapping: mapping, compositionTime: RationalTime(value: 2, timescale: 1)) == RationalTime(value: 9, timescale: 1))
}
