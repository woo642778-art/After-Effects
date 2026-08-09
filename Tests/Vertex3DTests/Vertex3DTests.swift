import Foundation
import Testing
@testable import Vertex3D

@Test("Cube primitive has canonical topology and bounds")
func cubeTopology() throws {
    let cube = Mesh3D.cube(size: 2)
    #expect(cube.vertices.count == 8)
    #expect(cube.triangles.count == 12)
    let bounds = try #require(cube.bounds)
    #expect(bounds.min == Vector3D(x: -1, y: -1, z: -1))
    #expect(bounds.max == Vector3D(x: 1, y: 1, z: 1))
}

@Test("Sphere generation is deterministic")
func sphereDeterministic() {
    let a = Mesh3D.sphere(radius: 2, segments: 8, rings: 4)
    let b = Mesh3D.sphere(radius: 2, segments: 8, rings: 4)
    #expect(a == b)
    #expect(a.vertices.count == 45)
    #expect(a.triangles.count == 64)
}

@Test("Subdivision creates four triangles per source triangle")
func subdivisionTopology() throws {
    let source = Mesh3D.plane()
    let result = try source.subdivided()
    #expect(result.triangles.count == source.triangles.count * 4)
    #expect(result.vertices.count > source.vertices.count)
}

@Test("Extrude creates a cap and six side triangles")
func extrudeFace() throws {
    let source = Mesh3D.plane()
    let result = try source.extrudingFace(at: 0, distance: 0.5)
    #expect(result.vertices.count == source.vertices.count + 3)
    #expect(result.triangles.count == source.triangles.count + 6)
}

@Test("Projection matrices remain finite and deterministic")
func projectionMath() {
    let a = ProjectionMath3D.perspective(fieldOfViewDegrees: 50, aspectRatio: 16.0 / 9.0, near: 0.01, far: 1000)
    let b = ProjectionMath3D.perspective(fieldOfViewDegrees: 50, aspectRatio: 16.0 / 9.0, near: 0.01, far: 1000)
    #expect(a == b)
    #expect(a.elements.allSatisfy { $0.isFinite })
}

@Test("glTF and GLB inspection reads scene counts")
func gltfInspection() throws {
    let json = Data("{\"scenes\":[{}],\"meshes\":[{},{}],\"materials\":[{}]}".utf8)
    let gltf = try Model3DInspector.inspect(data: json, fileExtension: "gltf")
    #expect(gltf.sceneCount == 1)
    #expect(gltf.meshCount == 2)
    #expect(gltf.materialCount == 1)

    var glb = Data([0x67, 0x6C, 0x54, 0x46, 0x02, 0, 0, 0])
    let total = UInt32(20 + json.count)
    withUnsafeBytes(of: total.littleEndian) { glb.append(contentsOf: $0) }
    let length = UInt32(json.count)
    withUnsafeBytes(of: length.littleEndian) { glb.append(contentsOf: $0) }
    glb.append(contentsOf: [0x4A, 0x53, 0x4F, 0x4E])
    glb.append(json)
    let inspected = try Model3DInspector.inspect(data: glb, fileExtension: "glb")
    #expect(inspected.meshCount == 2)
}

@Test("Starter scene includes mesh camera and light")
func starterScene() {
    let scene = Scene3DDocument.starter
    #expect(scene.nodes.count == 3)
    #expect(scene.activeCameraID != nil)
    #expect(scene.materials.count == 1)
}
