from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "App/BundledAIEnvironment+FrameEffects.swift"
text = path.read_text()
old = "import VertexAICoreML\nimport VertexMedia\n"
new = "import VertexAICoreML\nimport VertexCore\nimport VertexMedia\n"
if new not in text:
    if old not in text:
        raise RuntimeError("Frame effect backend import marker not found")
    text = text.replace(old, new, 1)
path.write_text(text)
print("Task 8 VertexCore import fix applied")
