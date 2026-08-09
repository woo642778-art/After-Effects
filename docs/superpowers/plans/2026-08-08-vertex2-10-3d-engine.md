# Vertex2 10 3D Engine and Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real motion-graphics-focused 2.5D/3D system to Vertex2 with 3D transforms, cameras, lights, GLB/glTF/USDZ import, editable meshes, materials, Metal rendering, and an AE-style 3D workspace integrated with the existing composition timeline.

**Architecture:** Extend canonical `VertexProject` data with versioned 3D scene structures and deterministic commands. Keep one project/timeline model and integrate a new `Vertex3D` portable scene module plus `VertexRender3DMetal` native renderer into the existing preview/export render path. The iPad 3D workspace is only a UI over those canonical structures.

**Tech Stack:** Swift 6, Foundation, simd, Model I/O where platform-supported, Metal/MetalKit, SwiftUI, existing VertexCore/VertexProject/VertexRender/VertexComposition animation and command infrastructure.

## Global Constraints

- 10.0.0 must preserve migrated 9.x 2D render semantics.
- 3D creative state is canonical project state and must participate in save, migration, recovery, and Undo/Redo.
- Viewport camera, shading mode, panel size, and selection are session/UI state unless represented as explicit scene content.
- GLB and glTF 2.0 import must normalize into Vertex-owned scene structures.
- USDZ import may use Model I/O but the stored/rendered representation remains Vertex-owned.
- Unsupported imported constructs must produce explicit diagnostics rather than silent corruption.
- The renderer must use Metal and must not fork preview and export semantics.
- Mesh edit operations must be deterministic and reject invalid topology before canonical mutation.
- Sculpting, rigging, skinning, physics, particles, UV unwrap authoring, and Blender-style node materials are out of scope.

---

## File Structure

### Project/schema
- Modify `Sources/VertexProject/ProjectLayer.swift`: 3D-capable transform and mesh scene source cases.
- Modify `Sources/VertexProject/ProjectSchema.swift`: schema bump and `sceneAssetRegistry`.
- Modify `Sources/VertexProject/ProjectCommand.swift` or the repository's canonical command payload file: 3D editing commands.
- Create `Sources/VertexProject/Project3DAsset.swift`: imported asset metadata and canonical scene payload references.
- Create `Sources/VertexProject/Project3DMaterial.swift`: PBR subset.
- Create `Sources/VertexProject/Project3DMesh.swift`: stable vertex/edge/face representation.
- Create `Sources/VertexProject/Project3DTransform.swift`: migration-safe transform model.
- Create migration coverage under `Tests/VertexProjectTests` and persistence coverage under `Tests/VertexProjectPersistenceTests`.

### Portable 3D module
- Add `Vertex3D` target in `Package.swift` and `Package@swift-6.0.swift` if needed by current package layout.
- Create `Sources/Vertex3D/SceneMath.swift`.
- Create `Sources/Vertex3D/MeshTopology.swift`.
- Create `Sources/Vertex3D/MeshOperations.swift`.
- Create `Sources/Vertex3D/GLTFImporter.swift`.
- Create `Sources/Vertex3D/GLBContainer.swift`.
- Create `Sources/Vertex3D/SceneNormalization.swift`.
- Create `Sources/Vertex3D/SceneDiagnostics.swift`.
- Create `Tests/Vertex3DTests/*`.

### Native import/render
- Create `Sources/Vertex3DModelIO/USDZImporter.swift`.
- Create `Sources/VertexRender3DMetal/MetalSceneRenderer.swift`.
- Create `Sources/VertexRender3DMetal/SceneGPUResources.swift`.
- Create `Sources/VertexRender3DMetal/Shaders/Vertex3DKernels.metal`.
- Create tests under `Tests/VertexRender3DMetalTests`.

### App UI
- Create `App/ThreeD/ThreeDWorkspaceView.swift`.
- Create `App/ThreeD/ThreeDViewportView.swift`.
- Create `App/ThreeD/ThreeDWorkspaceState.swift`.
- Create `App/ThreeD/SceneHierarchyView.swift`.
- Create `App/ThreeD/ThreeDInspectorView.swift`.
- Create `App/ThreeD/TransformGizmoView.swift`.
- Create `App/ThreeD/MeshEditToolbar.swift`.
- Create `App/ThreeD/ThreeDImportView.swift`.
- Create tests under `Tests/VertexAppTests`.

### Task 1: 3D transform model and 2D migration

**Files:**
- Create: `Sources/VertexProject/Project3DTransform.swift`
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Test: `Tests/VertexProjectTests/Project3DTransformTests.swift`

**Interfaces:**
- Produces `ProjectVector3`, `ProjectQuaternion`, `Project3DTransform`.
- `ProjectLayer` gains `is3D: Bool` and `transform3D: Project3DTransform` while retaining decode compatibility for existing `LayerTransform`.

- [ ] **Step 1: Write failing migration/math tests**

```swift
import XCTest
@testable import VertexProject

final class Project3DTransformTests: XCTestCase {
    func testIdentity3DTransformIsFiniteAndUnitScaled() throws {
        let t = Project3DTransform.identity
        XCTAssertEqual(t.position, .zero)
        XCTAssertEqual(t.scale, .one)
        XCTAssertEqual(t.orientation, .identity)
        XCTAssertNoThrow(try t.validated())
    }

    func testLegacy2DTransformMigratesWithoutChangingXY() {
        let old = LayerTransform(positionX: 0.25, positionY: 0.75, anchorX: 0.5, anchorY: 0.5, scaleX: 2, scaleY: 0.5, rotationDegrees: 30, opacity: 0.8)
        let migrated = Project3DTransform(legacy2D: old)
        XCTAssertEqual(migrated.position, ProjectVector3(x: 0.25, y: 0.75, z: 0))
        XCTAssertEqual(migrated.scale, ProjectVector3(x: 2, y: 0.5, z: 1))
        XCTAssertEqual(migrated.rotationZDegrees, 30)
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter Project3DTransformTests`
Expected: compile failure because the new types do not exist.

- [ ] **Step 3: Implement canonical transform types**

```swift
public struct ProjectVector3: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public static let zero = ProjectVector3(x: 0, y: 0, z: 0)
    public static let one = ProjectVector3(x: 1, y: 1, z: 1)
}

public struct ProjectQuaternion: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double
    public static let identity = ProjectQuaternion(x: 0, y: 0, z: 0, w: 1)
}

public struct Project3DTransform: Codable, Equatable, Sendable {
    public var position: ProjectVector3
    public var anchor: ProjectVector3
    public var scale: ProjectVector3
    public var orientation: ProjectQuaternion
    public var rotationXDegrees: Double
    public var rotationYDegrees: Double
    public var rotationZDegrees: Double

    public static let identity = Project3DTransform(
        position: .zero,
        anchor: .zero,
        scale: .one,
        orientation: .identity,
        rotationXDegrees: 0,
        rotationYDegrees: 0,
        rotationZDegrees: 0
    )
}
```

Add `validated()` requiring all components finite and all scale axes positive. Add `init(legacy2D:)` mapping Z to 0/1 and Z rotation to the old 2D rotation.

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VertexProject/Project3DTransform.swift Sources/VertexProject/ProjectLayer.swift Tests/VertexProjectTests/Project3DTransformTests.swift
git commit -m "feat: add migration safe 3D layer transforms"
```

### Task 2: Canonical mesh and material schema

**Files:**
- Create: `Sources/VertexProject/Project3DMesh.swift`
- Create: `Sources/VertexProject/Project3DMaterial.swift`
- Create: `Sources/VertexProject/Project3DAsset.swift`
- Test: `Tests/VertexProjectTests/Project3DAssetTests.swift`

**Interfaces:**
- Produces stable mesh IDs and a metallic-roughness material subset.

- [ ] **Step 1: Write schema validation tests**

```swift
func testTriangleMeshValidatesStableTopology() throws {
    let mesh = Project3DMesh.triangleFixture()
    XCTAssertNoThrow(try mesh.validated())
    XCTAssertEqual(Set(mesh.vertices.map(\.id)).count, 3)
    XCTAssertEqual(Set(mesh.faces.map(\.id)).count, 1)
}

func testMaterialRejectsInvalidRoughness() {
    var material = Project3DMaterial.default
    material.roughness = 1.5
    XCTAssertThrowsError(try material.validated())
}
```

- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement**

Use stable `VertexID` for `Project3DVertex`, `Project3DEdge`, and `Project3DFace`. A face stores an ordered `[VertexID]` with at least three distinct vertices. Material fields are:

```swift
public struct Project3DMaterial: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var name: String
    public var baseColor: ProjectRGBAColor
    public var baseColorTextureAssetID: VertexID?
    public var metallic: Double
    public var roughness: Double
    public var metallicRoughnessTextureAssetID: VertexID?
    public var normalTextureAssetID: VertexID?
    public var opacity: Double
    public var doubleSided: Bool
}
```

Validation requires metallic, roughness, opacity in `0...1` and all mesh references resolvable.

- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexProject/Project3DMesh.swift Sources/VertexProject/Project3DMaterial.swift Sources/VertexProject/Project3DAsset.swift Tests/VertexProjectTests/Project3DAssetTests.swift
git commit -m "feat: add canonical 3D mesh and PBR material schema"
```

### Task 3: Project schema bump and 9.x migration

**Files:**
- Modify: `Sources/VertexProject/ProjectSchema.swift`
- Modify current migration implementation under `Sources/VertexProject`.
- Test: `Tests/VertexProjectTests/ProjectSchemaMigrationTests.swift`
- Test: `Tests/VertexProjectPersistenceTests/CanonicalSchema1PackageMigrationTests.swift`

**Interfaces:**
- Produces schema version `6`, app version `10.0.0`, `sceneAssetRegistry: [Project3DAsset]`.

- [ ] **Step 1: Add migration fixture assertions**

Existing schema-5 fixtures must decode to schema 6 with empty `sceneAssetRegistry`, `is3D == false`, and transform values equivalent to the original 2D state.

- [ ] **Step 2: Verify current code fails**
- [ ] **Step 3: Bump schema and implement migration transactionally**

Set:

```swift
public static let currentSchemaVersion = 6
public static let currentAppVersion = "10.0.0"
```

Add `sceneAssetRegistry` with decode default `[]`. Migrate legacy layers through `Project3DTransform(legacy2D:)` without changing opacity, timing, effects, masks, animation, or z-order.

- [ ] **Step 4: Run project and persistence migration tests**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexProject Tests/VertexProjectTests Tests/VertexProjectPersistenceTests
git commit -m "feat: migrate Vertex projects to 3D capable schema 6"
```

### Task 4: Portable scene math and hierarchy

**Files:**
- Create: `Sources/Vertex3D/SceneMath.swift`
- Modify: package manifests to expose `Vertex3D`.
- Test: `Tests/Vertex3DTests/SceneMathTests.swift`

**Interfaces:**
- Produces `SceneMatrix`, `SceneTransformEvaluator.worldMatrix(for:parentMatrix:)`, camera view/projection matrix helpers.

- [ ] **Step 1: Write deterministic transform tests**

Test identity, translate-then-parent, rotation order, perspective near/far mapping, and orthographic editor projection.

- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement using `simd_double4x4` internally while exposing deterministic value wrappers to project consumers**
- [ ] **Step 4: Run `swift test --filter Vertex3DTests`**
- [ ] **Step 5: Commit**

```bash
git add Package.swift Package@swift-6.0.swift Sources/Vertex3D Tests/Vertex3DTests
git commit -m "feat: add portable Vertex 3D scene math"
```

### Task 5: Deterministic editable topology

**Files:**
- Create: `Sources/Vertex3D/MeshTopology.swift`
- Create: `Sources/Vertex3D/MeshOperations.swift`
- Test: `Tests/Vertex3DTests/MeshTopologyTests.swift`
- Test: `Tests/Vertex3DTests/MeshOperationsTests.swift`

**Interfaces:**
- Produces `EditableMesh`, `MeshSelection`, `MeshOperation`, `MeshOperationResult`.

- [ ] **Step 1: Write fixture tests for plane/cube primitives and topology invariants**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement adjacency-aware topology with these operations**

```swift
public enum MeshOperation: Equatable, Sendable {
    case moveVertices(ids: Set<VertexID>, delta: SIMD3<Double>)
    case deleteVertices(ids: Set<VertexID>)
    case deleteEdges(ids: Set<VertexID>)
    case deleteFaces(ids: Set<VertexID>)
    case extrudeFaces(ids: Set<VertexID>, distance: Double)
    case insetFaces(ids: Set<VertexID>, amount: Double)
    case bevelEdges(ids: Set<VertexID>, width: Double, segments: Int)
    case subdivideFaces(ids: Set<VertexID>)
    case mergeVertices(ids: Set<VertexID>, target: SIMD3<Double>)
}
```

Bound bevel segments to `1...4`. Reject nonfinite deltas/distances and any result containing dangling face references or faces with fewer than three unique vertices.

- [ ] **Step 4: Run tests twice and compare encoded mesh output byte-for-byte for deterministic IDs when the operation receives a seeded ID allocator**
- [ ] **Step 5: Commit**

```bash
git add Sources/Vertex3D/MeshTopology.swift Sources/Vertex3D/MeshOperations.swift Tests/Vertex3DTests
git commit -m "feat: add deterministic Vertex mesh editing"
```

### Task 6: GLB container and glTF 2.0 subset importer

**Files:**
- Create: `Sources/Vertex3D/GLBContainer.swift`
- Create: `Sources/Vertex3D/GLTFImporter.swift`
- Create: `Sources/Vertex3D/SceneDiagnostics.swift`
- Test: `Tests/Vertex3DTests/GLTFImporterTests.swift`
- Add small authored fixtures under `Tests/Vertex3DTests/Fixtures/`.

**Interfaces:**
- Produces `GLTFImporter.import(data:baseURL:) throws -> Project3DAsset` and explicit `SceneImportError`.

- [ ] **Step 1: Add fixtures for one triangle, indexed cube, textured PBR mesh, invalid accessor, unsupported skin**
- [ ] **Step 2: Verify importer tests fail**
- [ ] **Step 3: Implement GLB header/chunk parsing and glTF JSON subset**

Supported subset: scenes, nodes, meshes, primitives using POSITION/NORMAL/TEXCOORD_0, indices, node TRS, images/textures, baseColorFactor/baseColorTexture, metallicFactor, roughnessFactor, metallicRoughnessTexture, normalTexture, alphaMode OPAQUE/MASK/BLEND, doubleSided. Explicitly reject skins, morph targets, animation channels, Draco/meshopt compression unless separately supported by a tested dependency.

- [ ] **Step 4: Run importer tests and ensure unsupported constructs include their glTF path in diagnostics**
- [ ] **Step 5: Commit**

```bash
git add Sources/Vertex3D Tests/Vertex3DTests
git commit -m "feat: import tested GLB and glTF scene subset"
```

### Task 7: USDZ normalization through Model I/O

**Files:**
- Create: `Sources/Vertex3DModelIO/USDZImporter.swift`
- Modify: package manifests for a platform-native `Vertex3DModelIO` target.
- Test: `Tests/Vertex3DModelIOTests/USDZImporterTests.swift`

**Interfaces:**
- Produces `USDZImporter.import(url:) throws -> Project3DAsset`.

- [ ] **Step 1: Add a minimal deterministic USDZ fixture generated/checked into the test target**
- [ ] **Step 2: Verify test failure**
- [ ] **Step 3: Traverse `MDLAsset` meshes/materials, convert geometry and supported material semantics into the same `Project3DAsset` types used by glTF**
- [ ] **Step 4: Run native tests on macOS/iOS Simulator where Model I/O is available**
- [ ] **Step 5: Commit**

```bash
git add Package.swift Package@swift-6.0.swift Sources/Vertex3DModelIO Tests/Vertex3DModelIOTests
git commit -m "feat: normalize USDZ assets into Vertex 3D scenes"
```

### Task 8: Cameras, lights, and scene-layer command integration

**Files:**
- Modify: `Sources/VertexProject/ProjectLayer.swift`
- Modify: canonical project command payload implementation.
- Modify: `App/ProjectWorkspaceViewModel+Phase9UI.swift` or create `App/ProjectWorkspaceViewModel+Phase10ThreeD.swift`.
- Test: `Tests/VertexProjectTests/Project3DCommandTests.swift`

**Interfaces:**
- Produces commands for toggling 3D, adding/removing mesh object layers, editing transforms/materials/cameras/lights, and applying mesh operations.

- [ ] **Step 1: Add Undo/Redo command tests**

A mesh import followed by Undo must restore the exact pre-import encoded project document. Redo must restore the exact post-import encoding. Repeat for transform, material, camera, light, and mesh operation commands.

- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Add command payload cases with all creative writes routed through the existing `perform(_:mergeKey:)` path**
- [ ] **Step 4: Run project and app command tests**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexProject App/ProjectWorkspaceViewModel+Phase10ThreeD.swift Tests/VertexProjectTests/Project3DCommandTests.swift
git commit -m "feat: integrate 3D editing with Vertex project commands"
```

### Task 9: Metal 3D renderer foundation

**Files:**
- Create: `Sources/VertexRender3DMetal/SceneGPUResources.swift`
- Create: `Sources/VertexRender3DMetal/MetalSceneRenderer.swift`
- Create: `Sources/VertexRender3DMetal/Shaders/Vertex3DKernels.metal`
- Modify package manifests and `project.yml` resource/dependency declarations.
- Test: `Tests/VertexRender3DMetalTests/MetalSceneRendererTests.swift`

**Interfaces:**
- Produces `MetalSceneRenderer.render(scene:camera:size:quality:) throws -> MTLTexture` or the equivalent existing render-surface type used by `VertexRenderMetal`.

- [ ] **Step 1: Write native render fixtures**

Fixtures: colored triangle depth test, two overlapping meshes to prove Z-buffer behavior, directional-light Lambert/PBR sanity fixture, point light attenuation fixture, camera near/far clipping fixture.

- [ ] **Step 2: Verify native tests fail**
- [ ] **Step 3: Implement vertex/index buffers, depth texture, per-frame camera uniforms, material uniforms, point/directional/spot lights, opaque and alpha subset draw ordering**
- [ ] **Step 4: Run tests on Metal-capable macOS runner and iPad simulator/device build target**
- [ ] **Step 5: Commit**

```bash
git add Package.swift Package@swift-6.0.swift project.yml Sources/VertexRender3DMetal Tests/VertexRender3DMetalTests
git commit -m "feat: render Vertex 3D scenes with Metal"
```

### Task 10: Shadows, environment, and camera DOF quality tiers

**Files:**
- Modify: `Sources/VertexRender3DMetal/MetalSceneRenderer.swift`
- Modify: `Sources/VertexRender3DMetal/Shaders/Vertex3DKernels.metal`
- Test: `Tests/VertexRender3DMetalTests/MetalSceneRendererTests.swift`

**Interfaces:**
- Produces bounded `SceneRenderQuality` with preview/export values and deterministic shadow/DOF settings.

- [ ] **Step 1: Add tests for quality bounds and deterministic sample counts**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement one bounded shadow-map path for the selected shadow-casting light, environment/background contribution, and post/depth-based camera DOF using fixed sample kernels per quality tier**
- [ ] **Step 4: Verify test fixtures and measure memory allocation bounds on the selected iPad build configuration**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexRender3DMetal Tests/VertexRender3DMetalTests
git commit -m "feat: add bounded shadows and depth of field"
```

### Task 11: Integrate 3D rendering into composition preview/output semantics

**Files:**
- Modify existing composition render resolver under `Sources/VertexComposition`.
- Modify `App/CompositionPreviewController.swift` if required by the existing adapter boundary.
- Test: `Tests/VertexCompositionTests/ThreeDPreviewExportParityTests.swift`

**Interfaces:**
- Consumes the existing composition render graph and `MetalSceneRenderer`.
- Produces mixed 2D card/3D mesh/camera/light evaluation in the same composition output path.

- [ ] **Step 1: Add parity fixtures containing a 2D media layer behind a mesh, a mesh behind a 2D 3D-card layer, camera animation, and a light**
- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Insert a scene render node into the existing graph instead of building a second preview renderer; respect composition z/depth semantics and alpha compositing**
- [ ] **Step 4: Compare preview and output fixture hashes at exact rational times**
- [ ] **Step 5: Commit**

```bash
git add Sources/VertexComposition App/CompositionPreviewController.swift Tests/VertexCompositionTests/ThreeDPreviewExportParityTests.swift
git commit -m "feat: compose 2D and 3D through one render path"
```

### Task 12: 3D workspace UI and precise interaction

**Files:**
- Create: `App/ThreeD/ThreeDWorkspaceState.swift`
- Create: `App/ThreeD/ThreeDWorkspaceView.swift`
- Create: `App/ThreeD/ThreeDViewportView.swift`
- Create: `App/ThreeD/SceneHierarchyView.swift`
- Create: `App/ThreeD/ThreeDInspectorView.swift`
- Create: `App/ThreeD/TransformGizmoView.swift`
- Create: `App/ThreeD/MeshEditToolbar.swift`
- Create: `App/ThreeD/ThreeDImportView.swift`
- Modify: `App/IPadEditorWorkspaceView.swift`
- Test: `Tests/VertexAppTests/ThreeDWorkspaceInteractionTests.swift`

**Interfaces:**
- Consumes workspace preset `.threeD`, project commands, preview renderer, timeline and Graph Editor.
- Produces object/vertex/edge/face selection, gizmo manipulation, camera/light/material property editing, import, primitive creation.

- [ ] **Step 1: Write state/interaction tests**

Test mode transitions `.object -> .vertex -> .edge -> .face`, selection clearing rules, view-camera state remaining noncanonical, gizmo deltas producing project commands, and Pencil/touch using the same command semantics.

- [ ] **Step 2: Verify failure**
- [ ] **Step 3: Implement state**

```swift
enum ThreeDSelectionMode: String, CaseIterable { case object, vertex, edge, face }
enum ThreeDGizmoMode: String, CaseIterable { case translate, rotate, scale }
enum ThreeDViewMode: String, CaseIterable { case perspective, front, back, left, right, top, bottom, camera }

@MainActor
final class ThreeDWorkspaceState: ObservableObject {
    @Published var selectionMode: ThreeDSelectionMode = .object
    @Published var gizmoMode: ThreeDGizmoMode = .translate
    @Published var viewMode: ThreeDViewMode = .perspective
    @Published var selectedObjectIDs: Set<VertexID> = []
    @Published var selectedElementIDs: Set<VertexID> = []
    @Published var shadingMode: ThreeDShadingMode = .material
}
```

Build the left hierarchy, center Metal viewport, right inspector, and existing bottom timeline. Use explicit minimum hit targets and Apple Pencil precision, but do not require Pencil for any operation.

- [ ] **Step 4: Run app interaction tests and iPad simulator smoke tests**
- [ ] **Step 5: Commit**

```bash
git add App/ThreeD App/IPadEditorWorkspaceView.swift Tests/VertexAppTests/ThreeDWorkspaceInteractionTests.swift
git commit -m "feat: add AE style Vertex2 3D workspace"
```

### Task 13: Primitive creation and 3D text acceptance gate

**Files:**
- Modify: `Sources/Vertex3D/MeshTopology.swift`
- Create if feasible with deterministic output: `Sources/Vertex3D/TextMeshGenerator.swift`
- Test: `Tests/Vertex3DTests/PrimitiveMeshTests.swift`

**Interfaces:**
- Produces deterministic plane/cube/sphere primitives and, only if tests pass cross-run, deterministic 3D text mesh generation.

- [ ] **Step 1: Add exact vertex/face-count tests for plane/cube/sphere and encoded-output determinism**
- [ ] **Step 2: Implement primitives and run tests**
- [ ] **Step 3: Prototype text outlines through CoreText/CoreGraphics on Apple platforms, triangulate contours deterministically, extrude by a finite positive depth, and write a fixture test comparing topology counts and bounds**
- [ ] **Step 4: If text generation is deterministic across two clean native test runs, include it in 10.0.0; if not, do not expose the 3D Text UI in the release and record it explicitly in the 10.x follow-up section of release notes without claiming completion**
- [ ] **Step 5: Commit the passing implementation and acceptance decision**

```bash
git add Sources/Vertex3D Tests/Vertex3DTests Documentation
git commit -m "feat: add deterministic 3D primitives and text gate"
```

### Task 14: 3D native regression and performance gate

**Files:**
- Modify: `.github/workflows/phase-build.yml`
- Create: `Documentation/3D_10_ACCEPTANCE.md`

**Interfaces:**
- Produces reproducible evidence that project migration, import, topology, Metal render, composition parity, and iPad UI tests pass.

- [ ] **Step 1: Add CI jobs for portable `Vertex3DTests`, native Model I/O tests, Metal renderer tests, project migration tests, and iPad app tests**
- [ ] **Step 2: Run CI and retain the first real failing log for each red job rather than weakening assertions**
- [ ] **Step 3: Record tested fixture counts, supported import subset, unsupported constructs, render quality tiers, and measured memory/performance evidence in `Documentation/3D_10_ACCEPTANCE.md`**
- [ ] **Step 4: Re-run the complete 3D gate until green**
- [ ] **Step 5: Commit**

```bash
git add .github/workflows/phase-build.yml Documentation/3D_10_ACCEPTANCE.md
git commit -m "test: qualify Vertex2 10 3D pipeline"
```
