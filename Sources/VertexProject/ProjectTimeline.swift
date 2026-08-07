import Foundation
import VertexCore

public struct ProjectMarker: Codable, Equatable, Sendable, Identifiable {
    public var id: VertexID
    public var time: RationalTime
    public var name: String
    public var comment: String

    public init(
        id: VertexID = VertexID(),
        time: RationalTime,
        name: String,
        comment: String = ""
    ) {
        self.id = id
        self.time = time
        self.name = name
        self.comment = comment
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard time >= .zero, time < compositionDuration else {
            throw ProjectError.invalidValue("Marker time must satisfy 0 <= time < composition duration.")
        }
        return self
    }
}

public struct ProjectWorkArea: Codable, Equatable, Sendable {
    public var start: RationalTime
    public var end: RationalTime

    public init(start: RationalTime, end: RationalTime) {
        self.start = start
        self.end = end
    }

    public func validated(compositionDuration: RationalTime) throws -> Self {
        guard start >= .zero, start < end, end <= compositionDuration else {
            throw ProjectError.invalidValue("Work area must satisfy 0 <= start < end <= composition duration.")
        }
        return self
    }
}
