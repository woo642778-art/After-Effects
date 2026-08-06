import Foundation
import Testing
@testable import VertexProject
import VertexCore

@Test("Canonical project JSON excludes persistence implementation state")
func canonicalProjectExcludesPersistenceState() throws {
    var project = try ProjectDocument.makeNew(
        id: VertexID(rawValue: "51000000-0000-0000-0000-000000000001"),
        name: "Canonical",
        timestamp: Date(timeIntervalSince1970: 1_700_000_000)
    )
    project.mediaRegistry = [
        MediaReference(
            id: VertexID(rawValue: "51000000-0000-0000-0000-000000000002"),
            displayName: "clip.mov",
            originalFilename: "clip.mov",
            fileSize: 4,
            modificationDate: Date(timeIntervalSince1970: 1_700_000_001),
            contentFingerprint: "fixture",
            locator: MediaLocator(relativeHint: "clip.mov", embeddedPath: nil),
            kind: .video,
            availabilityStatus: .external
        )
    ]

    let json = String(decoding: try DeterministicProjectCodec().encode(project), as: UTF8.self)
    #expect(!json.contains("bookmarkData"))
    #expect(!json.contains("appliedCommandIDs"))
    #expect(!json.contains("legacyRenderSettings"))
    #expect(!json.contains("inverseOperation"))
    #expect(!json.contains("undo"))
    #expect(!json.contains("redo"))
}

@Test("Canonical media locator contains only portable path hints")
func canonicalMediaLocatorContainsPortableHints() throws {
    let locator = MediaLocator(relativeHint: "clip.mov", embeddedPath: "Media/clip.mov")
    let data = try JSONEncoder().encode(locator)
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains("relativeHint"))
    #expect(json.contains("embeddedPath"))
    #expect(!json.contains("bookmark"))
}
