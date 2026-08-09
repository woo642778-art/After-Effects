import Foundation
import VertexCore
import VertexProject

public struct BPMGrid: Sendable {
    public init() {}

    public func beatTimes(
        bpm: Double,
        subdivision: Int = 1,
        through duration: RationalTime,
        timescale: Int32 = 60_000
    ) throws -> [RationalTime] {
        guard bpm.isFinite, (1...999).contains(bpm), subdivision > 0, subdivision <= 64, timescale > 0 else {
            throw ProjectError.invalidValue("BPM grid parameters are outside supported ranges.")
        }
        let intervalSeconds = 60.0 / bpm / Double(subdivision)
        let intervalTicks = Int64((intervalSeconds * Double(timescale)).rounded())
        guard intervalTicks > 0 else { throw ProjectError.invalidValue("BPM subdivision is too fine for the selected timescale.") }
        let durationTicks = try duration.rescaled(to: timescale, rounding: .ceiling).value
        var result: [RationalTime] = []
        var tick: Int64 = 0
        while tick <= durationTicks {
            result.append(RationalTime(value: tick, timescale: timescale))
            let next = tick.addingReportingOverflow(intervalTicks)
            guard !next.overflow, next.partialValue > tick else { break }
            tick = next.partialValue
        }
        return result
    }

    public func snapped(
        time: RationalTime,
        bpm: Double,
        subdivision: Int = 1,
        duration: RationalTime
    ) throws -> RationalTime {
        let beats = try beatTimes(bpm: bpm, subdivision: subdivision, through: duration)
        guard let nearest = beats.min(by: { distance($0, time) < distance($1, time) }) else { return time }
        return nearest
    }

    private func distance(_ lhs: RationalTime, _ rhs: RationalTime) -> Double {
        abs(lhs.seconds - rhs.seconds)
    }
}
