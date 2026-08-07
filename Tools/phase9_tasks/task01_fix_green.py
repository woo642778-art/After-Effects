from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Sources/VertexProject/Schema3To4Migrator.swift"
text = path.read_text()
old = '        metadata.lastSavedByAppVersion = ProjectDocument.currentAppVersion\n'
new = '        metadata.lastSavedByAppVersion = "8.0.0"\n'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise RuntimeError("Schema3To4 metadata assignment marker not found")
path.write_text(text)
print("Task 1 GREEN migration fix applied")
