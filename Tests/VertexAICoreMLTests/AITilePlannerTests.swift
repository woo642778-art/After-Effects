import Testing
@testable import VertexAICoreML

private func coveredPixels(width: Int, height: Int, tiles: [AITile]) -> Set<Int> {
    var covered = Set<Int>()
    for tile in tiles {
        let rect = tile.outputRect
        for y in rect.y..<rect.maxY {
            for x in rect.x..<rect.maxX {
                covered.insert(y * width + x)
            }
        }
    }
    return covered
}

@Test("1080p tile plan covers every 4x output pixel exactly once after trimming")
func tilePlan1080p() throws {
    let tiles = try AITilePlanner.plan(width: 1920, height: 1080, tileSize: 512, overlap: 32, scale: 4)
    let outputWidth = 1920 * 4
    let outputHeight = 1080 * 4
    let covered = coveredPixels(width: outputWidth, height: outputHeight, tiles: tiles)
    #expect(covered.count == outputWidth * outputHeight)
    #expect(tiles.allSatisfy { $0.inputRect.width <= 512 && $0.inputRect.height <= 512 })
}

@Test("4K tile plan reaches all image edges")
func tilePlan4K() throws {
    let tiles = try AITilePlanner.plan(width: 3840, height: 2160, tileSize: 640, overlap: 48, scale: 2)
    #expect(tiles.first?.outputRect.x == 0)
    #expect(tiles.first?.outputRect.y == 0)
    #expect(tiles.map(\.outputRect.maxX).max() == 3840 * 2)
    #expect(tiles.map(\.outputRect.maxY).max() == 2160 * 2)
}

@Test("Invalid overlap is rejected")
func invalidOverlapRejected() {
    #expect(throws: Error.self) {
        _ = try AITilePlanner.plan(width: 100, height: 100, tileSize: 64, overlap: 32, scale: 2)
    }
}
