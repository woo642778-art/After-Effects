from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Tests/VertexAppTests/AIFrameEffectServiceTests.swift"
text = path.read_text()
old = "    #expect(await service.cachedImage(for: obsolete.key) == nil)\n"
new = "    #expect(try await service.cachedImage(for: obsolete.key) == nil)\n"
if new not in text:
    if old not in text:
        raise RuntimeError("Task 8 cache assertion marker not found")
    text = text.replace(old, new, 1)
path.write_text(text)
print("Task 8 throwing cache assertion fixed")
