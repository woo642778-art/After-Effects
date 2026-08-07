import Foundation
import VertexAI

public struct AITileRect: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Int { x + width }
    public var maxY: Int { y + height }
}

public struct AITile: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let inputRect: AITileRect
    /// Region of the input tile that survives overlap trimming, in tile-local coordinates.
    public let cropRect: AITileRect
    /// Non-overlapping destination region after scale is applied.
    public let outputRect: AITileRect
}

public enum AITilePlanner {
    public static func plan(
        width: Int,
        height: Int,
        tileSize: Int,
        overlap: Int,
        scale: Int
    ) throws -> [AITile] {
        guard width > 0, height > 0, tileSize > 0, scale > 0,
              overlap >= 0, overlap * 2 < tileSize else {
            throw AIError.invalidRecipe("Tile geometry requires positive dimensions and overlap smaller than half the tile size.")
        }

        let stride = tileSize - overlap * 2
        let xSegments = axisSegments(length: width, tileSize: tileSize, stride: stride)
        let ySegments = axisSegments(length: height, tileSize: tileSize, stride: stride)
        var result: [AITile] = []
        result.reserveCapacity(xSegments.count * ySegments.count)
        var id = 0

        for ySegment in ySegments {
            for xSegment in xSegments {
                let inputRect = AITileRect(
                    x: xSegment.start,
                    y: ySegment.start,
                    width: xSegment.length,
                    height: ySegment.length
                )
                let cropRect = AITileRect(
                    x: xSegment.keepStart - xSegment.start,
                    y: ySegment.keepStart - ySegment.start,
                    width: xSegment.keepEnd - xSegment.keepStart,
                    height: ySegment.keepEnd - ySegment.keepStart
                )
                let outputRect = AITileRect(
                    x: xSegment.keepStart * scale,
                    y: ySegment.keepStart * scale,
                    width: (xSegment.keepEnd - xSegment.keepStart) * scale,
                    height: (ySegment.keepEnd - ySegment.keepStart) * scale
                )
                result.append(AITile(id: id, inputRect: inputRect, cropRect: cropRect, outputRect: outputRect))
                id += 1
            }
        }
        return result
    }

    private struct AxisSegment {
        let start: Int
        let length: Int
        let keepStart: Int
        let keepEnd: Int
    }

    private static func axisSegments(length: Int, tileSize: Int, stride: Int) -> [AxisSegment] {
        let starts = starts(length: length, tileSize: tileSize, stride: stride)
        let lengths = starts.map { min(tileSize, length - $0) }
        return starts.indices.map { index in
            let start = starts[index]
            let end = start + lengths[index]

            let keepStart: Int
            if index == starts.startIndex {
                keepStart = 0
            } else {
                let previousEnd = starts[index - 1] + lengths[index - 1]
                keepStart = (previousEnd + start) / 2
            }

            let keepEnd: Int
            if index == starts.index(before: starts.endIndex) {
                keepEnd = length
            } else {
                let nextStart = starts[index + 1]
                keepEnd = (end + nextStart) / 2
            }

            precondition(keepStart >= start && keepEnd <= end && keepEnd > keepStart)
            return AxisSegment(start: start, length: lengths[index], keepStart: keepStart, keepEnd: keepEnd)
        }
    }

    private static func starts(length: Int, tileSize: Int, stride: Int) -> [Int] {
        guard length > tileSize else { return [0] }
        var result: [Int] = [0]
        var cursor = stride
        while cursor + tileSize < length {
            result.append(cursor)
            cursor += stride
        }
        let final = max(0, length - tileSize)
        if result.last != final { result.append(final) }
        return result
    }
}
