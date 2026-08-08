from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "App/ProjectWorkspaceViewModel.swift"
t = p.read_text()
old = '''    func bakeEffect(layerID: VertexID, effectID: VertexID) async throws {
        guard let project, let projectURL else { throw ProjectError.invalidOperation("Save the project package before baking AI output.") }
        let coordinator = AIEffectBakeCoordinator { [weak self] registration in
            self?.perform(.registerBakedAIEffect(registration), mergeKey: nil)
        }
        try await coordinator.bake(project: project, packageURL: projectURL, layerID: layerID, effectID: effectID)
    }
'''
new = '''    func bakeEffect(layerID: VertexID, effectID: VertexID) async throws {
        guard let project, let packageURL else { throw ProjectError.invalidOperation("Save the project package before baking AI output.") }
        let coordinator = AIEffectBakeCoordinator { [weak self] registration in
            self?.perform(.registerBakedAIEffect(registration), mergeKey: nil)
        }
        try await coordinator.bake(project: project, packageURL: packageURL, layerID: layerID, effectID: effectID)
    }
'''
if old in t:
    t = t.replace(old, new, 1)
elif new not in t:
    raise RuntimeError("Task 9 ViewModel bake wrapper anchor missing")
p.write_text(t)
print("Task 9 ViewModel now uses canonical packageURL")
