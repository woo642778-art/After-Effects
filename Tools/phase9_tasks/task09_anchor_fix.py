from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Tools/phase9_tasks/task09_green.py"
text = path.read_text()

replacements = [
    (
        "    case removeAIAsset(ProjectAIAsset, index: Int)\\n",
        "    case removeAIAsset(ProjectAIAsset)\\n",
    ),
    (
        "        case .removeAIAsset(let asset, let index): .registerAIAsset(asset, index: index)\\n",
        "        case .removeAIAsset(let asset): .registerAIAsset(asset)\\n",
    ),
    (
        '''        case .removeAIAsset(let id):\n            guard let index = document.aiAssetRegistry.firstIndex(where: { $0.id == id }) else {\n                throw ProjectError.invalidOperation(\"AI asset is missing.\")\n            }\n            forward = .removeAIAsset(document.aiAssetRegistry[index], index: index)\n''',
        '''        case .removeAIAsset(let id):\n            guard let asset = document.aiAsset(id: id) else {\n                throw ProjectError.invalidOperation(\"AI asset is missing.\")\n            }\n            forward = .removeAIAsset(asset)\n''',
    ),
    (
        '''        case .removeAIAsset(let asset, let index):\n            guard document.aiAssetRegistry.indices.contains(index), document.aiAssetRegistry[index] == asset else {\n                throw ProjectError.invalidOperation(\"AI asset removal precondition did not match.\")\n            }\n            document.aiAssetRegistry.remove(at: index)\n''',
        '''        case .removeAIAsset(let asset):\n            guard let index = document.aiAssetRegistry.firstIndex(of: asset) else {\n                throw ProjectError.invalidOperation(\"AI asset removal precondition did not match.\")\n            }\n            document.aiAssetRegistry.remove(at: index)\n''',
    ),
]

changed = 0
for old, new in replacements:
    if old in text:
        text = text.replace(old, new, 1)
        changed += 1

if changed != len(replacements):
    raise RuntimeError(f"Task 9 anchor fixer expected {len(replacements)} replacements, applied {changed}")

path.write_text(text)
print("Task 9 generator anchors aligned with current ProjectMutation/ProjectCommands APIs")
