from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/"Tests/VertexCompositionTests/EffectGraphCompilerTests.swift"
t=p.read_text()
t=t.replace('''    let evaluated = try #require(await effects.effects().first)
    #expect(evaluated.parameter(id: DepthMapParameterID.smoothing)?.value == .scalar(0.5))
''','''    let recordedEffects = await effects.effects()
    let evaluated = try #require(recordedEffects.first)
    #expect(evaluated.parameter(id: DepthMapParameterID.smoothing)?.value == .scalar(0.5))
''')
t=t.replace('''    #expect(await resolverA.effectTypes() == [.depthMap])
    #expect(await resolverB.effectTypes().isEmpty)
''','''    let withTypes = await resolverA.effectTypes()
    let withoutTypes = await resolverB.effectTypes()
    #expect(withTypes == [.depthMap])
    #expect(withoutTypes.isEmpty)
''')
p.write_text(t)
