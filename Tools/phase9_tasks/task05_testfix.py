from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/"Tests/VertexProjectTests/ProjectEffectCommandTests.swift"
t=p.read_text()
if not t.startswith("import Foundation"):
    t="import Foundation\n"+t
p.write_text(t)
