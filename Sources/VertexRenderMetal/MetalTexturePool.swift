#if canImport(Metal)
@preconcurrency import Metal
import Foundation
import VertexRender

internal final class MetalTexturePool: @unchecked Sendable {
    private struct Key: Hashable {
        var width: Int
        var height: Int
    }

    private let resources: MetalRenderResources
    private var free: [Key: [any MTLTexture]] = [:]
    private var liveBytesByObject: [ObjectIdentifier: Int] = [:]
    private(set) var estimatedPeakBytes = 0

    init(resources: MetalRenderResources) {
        self.resources = resources
    }

    func acquire(width: Int, height: Int) throws -> any MTLTexture {
        let key = Key(width: width, height: height)
        let texture: any MTLTexture
        if var available = free[key], let reused = available.popLast() {
            free[key] = available
            texture = reused
        } else {
            texture = try resources.makeTexture(width: width, height: height)
        }
        let object = ObjectIdentifier(texture as AnyObject)
        let bytes = width * height * 4
        liveBytesByObject[object] = bytes
        estimatedPeakBytes = max(estimatedPeakBytes, liveBytesByObject.values.reduce(0, +))
        return texture
    }

    func release(_ texture: any MTLTexture) {
        let object = ObjectIdentifier(texture as AnyObject)
        liveBytesByObject.removeValue(forKey: object)
        let key = Key(width: texture.width, height: texture.height)
        free[key, default: []].append(texture)
    }
}
#endif
