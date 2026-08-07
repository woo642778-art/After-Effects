import Testing
@testable import VertexAICoreML

private func area(_ rect: AITileRect) -> Int {
    rect.width * rect.height
}

private func intersectionArea(_ lhs: AITileRect, _ rhs: AITileRect) -> Int {
    let minX = max(lhs.x, rhs.x)
    let minY = max(lhs.y, rhs.y)
    let maxX = min(lhs.maxX, rhs.maxX)
    let maxY = min(lhs.maxY, rhs.maxY)
    guard maxX > minX, maxY > minY else { return 0 }
    return (maxX - minX) * (maxY - minY)
}

private func assertExactCoverage(width: Int, height: Int, tiles: [AITile]) {
    #expect(tiles.map { area($0.outputRect) }.reduce(0, +) == width * height)
    #expect(tiles.map(\.outputRect.x).min() == 0)
    #expect(tiles.map(\.outputRect.y).min() == 0)
    #expect(tiles.map(\.outputRect.maxX).max() == width)
    #expect(tiles.map(\.outputRect.maxY).max() == height)
    for first in tiles.indices {
        for second in tiles.indices where second > first {
            #expect(intersectionArea(tiles[first].outputRect, tiles[second].outputRect) == 0)
        }
    }
}

@Test("1080p tile plan covers every 4x output pixel exactly once after trimming")
func tilePlan1080p() throws {
    let tiles = try AITilePlanner.plan(width: 1920, height: 1080, tileSize: 512, overlap: 32, scale: 4)
    assertExactCoverage(width: 1920 * 4, height: 1080 * 4, tiles: tiles)
    #expect(tiles.allSatisfy { $0.inputRect.width <= 512 && $0.inputRect.height <= 512 })
}

@Test("4K tile plan reaches all image edges")
func tilePlan4K() throws {
    let tiles = try AITilePlanner.plan(width: 3840, height: 2160, tileSize: 640, overlap: 48, scale: 2)
    assertExactCoverage(width: 3840 * 2, height: 2160 * 2, tiles: tiles)
}

@Test("Invalid overlap is rejected")
func invalidOverlapRejected() {
    #expect(throws: Error.self) {
        _ = try AITilePlanner.plan(width: 100, height: 100, tileSize: 64, overlap: 32, scale: 2)
    }
}
