import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ProjectPackageFileDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.vertexProject] }
    static var writableContentTypes: [UTType] { [.vertexProject] }

    private let wrapper: FileWrapper

    init(packageURL: URL) throws {
        guard packageURL.pathExtension.lowercased() == ProjectDocumentTypes.canonicalExtension else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let wrapper = try FileWrapper(url: packageURL, options: [.immediate])
        wrapper.preferredFilename = packageURL.lastPathComponent
        self.wrapper = wrapper
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isDirectory else {
            throw CocoaError(.fileReadCorruptFile)
        }
        wrapper = configuration.file
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        wrapper
    }
}
