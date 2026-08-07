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
    /// Region of the input tile that should survive overlap trimming.
    public let cropRect: AITileRect
    /// Destination region after scale is applied.
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

        if width <= tileSize, height <= tileSize {
            let input = AITileRect(x: 0, y: 0, width: width, height: height)
            return [AITile(
                id: 0,
                inputRect: input,
                cropRect: AITileRect(x: 0, y: 0, width: width, height: height),
                outputRect: AITileRect(x: 0, y: 0, width: width * scale, height: height * scale)
            )]
        }

        let stride = tileSize - overlap * 2
        let xs = starts(length: width, tileSize: tileSize, stride: stride)
        let ys = starts(length: height, tileSize: tileSize, stride: stride)
        var tiles: [AITile] = []
        var id = 0

        for y in ys {
            for x in xs {
                let tileWidth = min(tileSize, width - x)
                let tileHeight = min(tileSize, height - y)
                let leftTrim = x == 0 ? 0 : min(overlap, tileWidth - 1)
                let topTrim = y == 0 ? 0 : min(overlap, tileHeight - 1)
                let rightTrim = x + tileWidth == width ? 0 : min(overlap, tileWidth - leftTrim - 1)
                let bottomTrim = y + tileHeight == height ? 0 : min(overlap, tileHeight - topTrim - 1)
                let keptWidth = tileWidth - leftTrim - rightTrim
                let keptHeight = tileHeight - topTrim - bottomTrim

                let inputRect = AITileRect(x: x, y: y, width: tileWidth, height: tileHeight)
                let cropRect = AITileRect(
                    x: leftTrim,
                    y: topTrim,
                    width: keptWidth,
                    height: keptHeight
                )
                let outputRect = AITileRect(
                    x: (x + leftTrim) * scale,
                    y: (y + topTrim) * scale,
                    width: keptWidth * scale,
                    height: keptHeight * scale
                )
                tiles.append(AITile(id: id, inputRect: inputRect, cropRect: cropRect, outputRect: outputRect))
                id += 1
            }
        }
        return tiles
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
