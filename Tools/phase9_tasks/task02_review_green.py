from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / "Sources/VertexTimeline/TimelineEngine.swift"
text = path.read_text()

text = text.replace(
'''                var layer = try current(id)
                layer.timing = try shifted(layer.timing, by: delta, composition: composition)
                try store(layer)
''',
'''                let layer = try shiftedLayer(try current(id), by: delta, composition: composition)
                try store(layer)
''',
1,
)
text = text.replace(
'''                var layer = try current(id)
                layer.timing = try shifted(layer.timing, by: delta, composition: composition)
                try store(layer)
''',
'''                let layer = try shiftedLayer(try current(id), by: delta, composition: composition)
                try store(layer)
''',
1,
)
text = text.replace(
'''            var selected = try current(layerID)
            guard isSourceBacked(selected.source) else {
''',
'''            var selected = try current(layerID)
            guard isSourceBacked(selected.source) else {
''',
1,
)
old_slide = '''            selected.timing = try shifted(selected.timing, by: delta, composition: composition)
'''
new_slide = '''            selected = try shiftedLayer(selected, by: delta, composition: composition)
'''
if old_slide in text:
    text = text.replace(old_slide, new_slide, 1)
elif new_slide not in text:
    raise RuntimeError("Slide shift marker not found")

anchor = '''    private func shifted(
        _ timing: LayerTiming,
        by delta: RationalTime,
        composition: ProjectComposition
    ) throws -> LayerTiming {
'''
helper = r'''    private func shiftedLayer(
        _ layer: ProjectLayer,
        by delta: RationalTime,
        composition: ProjectComposition
    ) throws -> ProjectLayer {
        var result = layer
        result.timing = try shifted(result.timing, by: delta, composition: composition)
        result.animationChannels = try result.animationChannels.map { channel in
            var shiftedChannel = channel
            shiftedChannel.keyframes = try channel.keyframes.map { keyframe in
                var shiftedKeyframe = keyframe
                shiftedKeyframe.time = try add(keyframe.time, delta)
                guard shiftedKeyframe.time >= .zero else {
                    throw ProjectError.invalidOperation("Moving the layer would place an animation keyframe before composition time zero.")
                }
                return shiftedKeyframe
            }
            return try shiftedChannel.validated()
        }
        return result
    }

'''
if helper not in text:
    if anchor not in text:
        raise RuntimeError("Timeline helper insertion marker not found")
    text = text.replace(anchor, helper + anchor, 1)

# Ensure both whole-layer shift call sites were actually replaced.
if text.count("shiftedLayer(try current(id), by: delta") < 2:
    raise RuntimeError("Move/ripple whole-layer shift call sites were not both patched")

path.write_text(text)
print("Task 2 review GREEN fix applied")
