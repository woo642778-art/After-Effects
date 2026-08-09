import SwiftUI
import MetalKit
import UniformTypeIdentifiers
import Vertex3D
import VertexRender3DMetal

enum Vertex3DEditMode: String, CaseIterable, Identifiable {
    case object = "Object"
    case vertex = "Vertex"
    case edge = "Edge"
    case face = "Face"
    var id: String { rawValue }
}

@MainActor
final class ThreeDWorkspaceViewModel: ObservableObject {
    @Published var scene = Scene3DDocument.starter
    @Published var selectedNodeID: UUID?
    @Published var editMode: Vertex3DEditMode = .object
    @Published var errorMessage: String?
    @Published var importedAssetDescription: String?

    private let packageStore = Scene3DPackageStore()
    private var packageURL: URL?
    private var saveTask: Task<Void, Never>?

    var selectedNode: Scene3DNode? {
        guard let selectedNodeID else { return nil }
        return scene.nodes.first { $0.id == selectedNodeID }
    }

    func load(packageURL: URL?) async {
        self.packageURL = packageURL
        guard let packageURL else {
            scene = .starter
            selectedNodeID = scene.nodes.first?.id
            return
        }
        do {
            scene = try await packageStore.load(from: packageURL)
            selectedNodeID = scene.nodes.first?.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ id: UUID) { selectedNodeID = id }

    func addPrimitive(_ kind: Primitive3DKind) {
        let mesh: Mesh3D
        switch kind {
        case .cube: mesh = .cube(size: 2)
        case .sphere: mesh = .sphere(radius: 1)
        case .plane: mesh = .plane(width: 3, depth: 3)
        }
        let materialID = ensureDefaultMaterial()
        let node = Scene3DNode(name: kind.rawValue.capitalized, payload: .mesh(mesh, materialID: materialID))
        scene.nodes.append(node)
        selectedNodeID = node.id
        scheduleSave()
    }

    func addCamera() {
        let count = scene.nodes.filter { if case .camera = $0.payload { return true }; return false }.count + 1
        let node = Scene3DNode(
            name: "Camera \(count)",
            transform: Transform3D(position: Vector3D(x: 0, y: 0, z: 6)),
            payload: .camera(Camera3D())
        )
        scene.nodes.append(node)
        scene.activeCameraID = node.id
        selectedNodeID = node.id
        scheduleSave()
    }

    func addLight() {
        let count = scene.nodes.filter { if case .light = $0.payload { return true }; return false }.count + 1
        let node = Scene3DNode(
            name: "Light \(count)",
            transform: Transform3D(rotationDegrees: Vector3D(x: -35, y: 35, z: 0)),
            payload: .light(Light3D())
        )
        scene.nodes.append(node)
        selectedNodeID = node.id
        scheduleSave()
    }

    func deleteSelected() {
        guard let selectedNodeID else { return }
        scene.nodes.removeAll { $0.id == selectedNodeID }
        if scene.activeCameraID == selectedNodeID {
            scene.activeCameraID = scene.nodes.first { if case .camera = $0.payload { return true }; return false }?.id
        }
        self.selectedNodeID = scene.nodes.first?.id
        scheduleSave()
    }

    func nudgePosition(axis: Int, delta: Double) {
        mutateSelectedNode { node in
            switch axis {
            case 0: node.transform.position.x += delta
            case 1: node.transform.position.y += delta
            default: node.transform.position.z += delta
            }
        }
    }

    func nudgeRotation(axis: Int, delta: Double) {
        mutateSelectedNode { node in
            switch axis {
            case 0: node.transform.rotationDegrees.x += delta
            case 1: node.transform.rotationDegrees.y += delta
            default: node.transform.rotationDegrees.z += delta
            }
        }
    }

    func scaleSelected(by factor: Double) {
        mutateSelectedNode { node in
            node.transform.scale.x = max(0.001, node.transform.scale.x * factor)
            node.transform.scale.y = max(0.001, node.transform.scale.y * factor)
            node.transform.scale.z = max(0.001, node.transform.scale.z * factor)
        }
    }

    func subdivideSelected() { mutateSelectedMesh { try $0.subdivided() } }
    func flipSelectedNormals() { mutateSelectedMesh { $0.flippedNormals() } }
    func mergeSelectedVertices() { mutateSelectedMesh { try $0.mergedVertices() } }
    func extrudeFirstFace() { mutateSelectedMesh { try $0.extrudingFace(at: 0, distance: 0.2) } }
    func insetFirstFace() { mutateSelectedMesh { try $0.insettingFace(at: 0, factor: 0.2) } }
    func bevelFirstFace() { mutateSelectedMesh { try $0.bevelingFace(at: 0, width: 0.12) } }

    func importModel(from url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let mesh: Mesh3D
            if url.pathExtension.lowercased() == "usdz" {
                mesh = try AppleModel3DImporter.loadMesh(from: url)
            } else {
                mesh = try Model3DImporter.loadMesh(from: url)
            }
            let descriptor = try Model3DInspector.inspect(data: Data(contentsOf: url), fileExtension: url.pathExtension)
            let materialID = ensureDefaultMaterial()
            let node = Scene3DNode(name: url.deletingPathExtension().lastPathComponent, payload: .mesh(mesh, materialID: materialID))
            scene.nodes.append(node)
            selectedNodeID = node.id
            importedAssetDescription = "\(descriptor.format.rawValue.uppercased()) · \(mesh.vertices.count) vertices · \(mesh.triangles.count) triangles"
            errorMessage = nil
            scheduleSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureDefaultMaterial() -> UUID {
        if let existing = scene.materials.first { return existing.id }
        let material = Material3D(name: "Default")
        scene.materials.append(material)
        return material.id
    }

    private func mutateSelectedNode(_ body: (inout Scene3DNode) -> Void) {
        guard let selectedNodeID, let index = scene.nodes.firstIndex(where: { $0.id == selectedNodeID }) else { return }
        body(&scene.nodes[index])
        scheduleSave()
    }

    private func mutateSelectedMesh(_ operation: (Mesh3D) throws -> Mesh3D) {
        guard let selectedNodeID,
              let index = scene.nodes.firstIndex(where: { $0.id == selectedNodeID }),
              case .mesh(let mesh, let materialID) = scene.nodes[index].payload else { return }
        do {
            scene.nodes[index].payload = .mesh(try operation(mesh), materialID: materialID)
            errorMessage = nil
            scheduleSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        guard let packageURL else { return }
        let snapshot = scene
        saveTask?.cancel()
        saveTask = Task { [packageStore] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            try? await packageStore.save(snapshot, to: packageURL)
        }
    }
}

struct ThreeDWorkspaceView: View {
    @EnvironmentObject private var workspace: ProjectWorkspaceViewModel
    @StateObject private var model = ThreeDWorkspaceViewModel()
    @State private var importerPresented = false

    private var supportedModelTypes: [UTType] {
        ["gltf", "glb", "usdz"].compactMap { UTType(filenameExtension: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                outliner.frame(width: 230)
                Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
                ThreeDMetalViewport(scene: model.scene).frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(AfterEffectsTheme.border).frame(width: 1)
                inspector.frame(width: 300)
            }
        }
        .background(AfterEffectsTheme.background)
        .task(id: workspace.packageURL) { await model.load(packageURL: workspace.packageURL) }
        .fileImporter(isPresented: $importerPresented, allowedContentTypes: supportedModelTypes) { result in
            switch result {
            case .success(let url): Task { await model.importModel(from: url) }
            case .failure(let error): model.errorMessage = error.localizedDescription
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("3D").font(.caption.bold()).foregroundStyle(AfterEffectsTheme.accent)
            Menu("Add") {
                Button("Cube") { model.addPrimitive(.cube) }
                Button("Sphere") { model.addPrimitive(.sphere) }
                Button("Plane") { model.addPrimitive(.plane) }
                Divider()
                Button("Camera") { model.addCamera() }
                Button("Light") { model.addLight() }
            }
            .menuStyle(.button)
            Button("Import Model") { importerPresented = true }
            Picker("Edit Mode", selection: $model.editMode) {
                ForEach(Vertex3DEditMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            Spacer()
            if let description = model.importedAssetDescription {
                Text(description).font(.caption2).foregroundStyle(AfterEffectsTheme.secondaryText)
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(AfterEffectsTheme.elevatedPanel)
    }

    private var outliner: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCENE").font(.caption2.bold()).foregroundStyle(AfterEffectsTheme.secondaryText)
                Spacer()
                Button(role: .destructive) { model.deleteSelected() } label: { Image(systemName: "trash") }.buttonStyle(.plain)
            }
            .padding(9)
            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.scene.nodes) { node in
                        Button { model.select(node.id) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: icon(for: node.payload)).frame(width: 18)
                                Text(node.name).lineLimit(1)
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundStyle(AfterEffectsTheme.primaryText)
                            .padding(.horizontal, 8)
                            .frame(height: 30)
                            .background(model.selectedNodeID == node.id ? AfterEffectsTheme.selection : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
            }
        }
        .background(AfterEffectsTheme.panel)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("3D PROPERTIES").font(.caption2.bold()).foregroundStyle(AfterEffectsTheme.secondaryText)
                if let node = model.selectedNode {
                    Text(node.name).font(.headline).foregroundStyle(AfterEffectsTheme.primaryText)
                    transformGroup(title: "Position", values: node.transform.position, step: 0.25) { axis, value in model.nudgePosition(axis: axis, delta: value) }
                    transformGroup(title: "Rotation", values: node.transform.rotationDegrees, step: 5) { axis, value in model.nudgeRotation(axis: axis, delta: value) }
                    HStack {
                        Text("Scale").font(.caption)
                        Spacer()
                        Button("−") { model.scaleSelected(by: 0.9) }
                        Text(String(format: "%.2f", node.transform.scale.x)).font(.caption.monospacedDigit())
                        Button("+") { model.scaleSelected(by: 1.1) }
                    }
                    if case .mesh(let mesh, _) = node.payload {
                        Divider()
                        Text("MESH · \(mesh.vertices.count) V · \(mesh.triangles.count) T")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AfterEffectsTheme.secondaryText)
                        meshButtons
                    }
                } else {
                    Text("Select a 3D object").font(.caption).foregroundStyle(AfterEffectsTheme.secondaryText)
                }
                if let error = model.errorMessage {
                    Divider()
                    Text(error).font(.caption2).foregroundStyle(.orange)
                }
            }
            .padding(12)
        }
        .background(AfterEffectsTheme.panel)
    }

    private var meshButtons: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Extrude") { model.extrudeFirstFace() }
                Button("Inset") { model.insetFirstFace() }
                Button("Bevel") { model.bevelFirstFace() }
            }
            HStack {
                Button("Subdivide") { model.subdivideSelected() }
                Button("Merge") { model.mergeSelectedVertices() }
                Button("Flip Normals") { model.flipSelectedNormals() }
            }
        }
        .buttonStyle(.bordered)
        .font(.caption2)
    }

    private func transformGroup(title: String, values: Vector3D, step: Double, action: @escaping (Int, Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.semibold))
            ForEach(Array([("X", values.x), ("Y", values.y), ("Z", values.z)].enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0).font(.caption2.bold()).frame(width: 14)
                    Button("−") { action(index, -step) }
                    Text(String(format: "%.2f", item.1)).font(.caption2.monospacedDigit()).frame(maxWidth: .infinity)
                    Button("+") { action(index, step) }
                }
            }
        }
    }

    private func icon(for payload: Scene3DNodePayload) -> String {
        switch payload {
        case .mesh: "cube"
        case .camera: "video"
        case .light: "lightbulb"
        case .group: "square.3.layers.3d"
        }
    }
}

private struct ThreeDMetalViewport: UIViewRepresentable {
    let scene: Scene3DDocument

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        context.coordinator.renderer = try? MetalSceneRenderer(view: view, scene: scene)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.scene = scene
        uiView.setNeedsDisplay()
    }

    final class Coordinator {
        var renderer: MetalSceneRenderer?
    }
}
