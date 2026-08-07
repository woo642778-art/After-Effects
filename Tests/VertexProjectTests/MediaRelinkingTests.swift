import Foundation
import Testing
@testable import VertexProject

@Test("Filename alone is not a strong relink")
func filenameAloneIsRejected() {
    let reference = MediaReference.fixture(name: "clip.mov", fileSize: 100, fingerprint: "abc")
    let weak = MediaRelinkCandidate(
        displayName: "clip.mov",
        fileSize: 999,
        modificationDate: nil,
        fingerprint: nil,
        locatorToken: "weak"
    )
    #expect(MediaRelinker().decide(reference: reference, candidates: [weak]) == .requiresUserSelection([weak]))
}

@Test("Matching fingerprint produces an automatic relink")
func fingerprintMatchIsStrong() {
    let reference = MediaReference.fixture(name: "clip.mov", fileSize: 100, fingerprint: "abc")
    let strong = MediaRelinkCandidate(
        displayName: "renamed.mov",
        fileSize: 100,
        modificationDate: nil,
        fingerprint: "abc",
        locatorToken: "strong"
    )
    #expect(MediaRelinker().decide(reference: reference, candidates: [strong]) == .automatic(strong))
}

@Test("Multiple fingerprint matches require user selection")
func ambiguousStrongMatchesRequireSelection() {
    let reference = MediaReference.fixture(name: "clip.mov", fileSize: 100, fingerprint: "abc")
    let first = MediaRelinkCandidate(displayName: "one.mov", fileSize: 100, modificationDate: nil, fingerprint: "abc", locatorToken: "one")
    let second = MediaRelinkCandidate(displayName: "two.mov", fileSize: 100, modificationDate: nil, fingerprint: "abc", locatorToken: "two")
    #expect(MediaRelinker().decide(reference: reference, candidates: [first, second]) == .requiresUserSelection([first, second]))
}

@Test("No candidates reports missing media")
func noCandidatesIsMissing() {
    let reference = MediaReference.fixture()
    #expect(MediaRelinker().decide(reference: reference, candidates: []) == .missing)
}
