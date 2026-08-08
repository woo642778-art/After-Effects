from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Sources/VertexComposition/LayerAnimationEvaluator.swift"
text = path.read_text()
old = '''        for channel in layer.animationChannels {
            let value = try channel.evaluatedValue(at: time)
'''
new = '''        for channel in layer.animationChannels {
            if case .effect = channel.property { continue }
            let value = try channel.evaluatedValue(at: time)
'''
if new not in text:
    if old not in text:
        raise RuntimeError("LayerAnimationEvaluator loop marker not found")
    text = text.replace(old, new, 1)
path.write_text(text)
print("Task 6 effect-channel isolation fix applied")
