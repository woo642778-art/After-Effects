import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let afterEffectsProject = UTType(
        exportedAs: "com.woo642778.aftereffects.project",
        conformingTo: .package
    )
}

struct ProjectPackageFileDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.afterEffectsProject] }

    private let wrapper: FileWrapper

    init(packageURL: URL) throws {
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
