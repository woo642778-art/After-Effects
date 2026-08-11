import Foundation

enum ParticleRandom {
    static func mixed(_ seed: UInt64, _ index: UInt64, _ lane: UInt64) -> UInt64 {
        var value = seed &+ 0x9E3779B97F4A7C15 &* (index &+ 1) &+ 0xBF58476D1CE4E5B9 &* (lane &+ 1)
        value ^= value >> 30
        value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value &*= 0x94D049BB133111EB
        value ^= value >> 31
        return value
    }

    static func unit(_ seed: UInt64, _ index: Int, _ lane: UInt64) -> Double {
        let bits = mixed(seed, UInt64(bitPattern: Int64(index)), lane) >> 11
        return Double(bits) / Double(UInt64(1) << 53)
    }

    static func signed(_ seed: UInt64, _ index: Int, _ lane: UInt64) -> Double {
        unit(seed, index, lane) * 2 - 1
    }
}
