import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

package enum DurableFileFailurePoint: String, CaseIterable, Sendable {
    case afterWrite
    case afterFileSync
    case afterRename
    case afterDirectorySync
}

package struct DurableFileIO: Sendable {
    package let failurePoint: DurableFileFailurePoint?
    private let fileManager: FileManager

    package init(
        fileManager: FileManager = .default,
        failurePoint: DurableFileFailurePoint? = nil
    ) {
        self.fileManager = fileManager
        self.failurePoint = failurePoint
    }

    package func writeAndSynchronize(_ data: Data, to temporaryURL: URL) throws {
        do {
            try removeIfPresent(temporaryURL)
            guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
                throw ProjectPersistenceError.atomicReplacementFailed(
                    "Temporary file could not be created at \(temporaryURL.lastPathComponent)."
                )
            }
            let handle = try FileHandle(forWritingTo: temporaryURL)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            if failurePoint == .afterWrite {
                throw ProjectPersistenceError.atomicReplacementFailed("Injected failure after write.")
            }
            try handle.synchronize()
            if failurePoint == .afterFileSync {
                throw ProjectPersistenceError.atomicReplacementFailed("Injected failure after file synchronization.")
            }
        } catch let error as ProjectPersistenceError {
            throw error
        } catch {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Temporary file could not be written durably: \(error.localizedDescription)"
            )
        }
    }

    package func atomicPromote(_ temporaryURL: URL, to destinationURL: URL) throws {
        let result: Int32 = temporaryURL.path.withCString { source in
            destinationURL.path.withCString { destination in
                #if canImport(Darwin)
                Darwin.rename(source, destination)
                #elseif canImport(Glibc)
                Glibc.rename(source, destination)
                #else
                -1
                #endif
            }
        }
        guard result == 0 else {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Atomic rename failed for \(destinationURL.lastPathComponent)."
            )
        }
        if failurePoint == .afterRename {
            throw ProjectPersistenceError.atomicReplacementFailed("Injected failure after rename.")
        }
    }

    package func synchronizeDirectory(_ url: URL) throws {
        let descriptor: Int32 = url.path.withCString { path in
            #if canImport(Darwin)
            Darwin.open(path, O_RDONLY)
            #elseif canImport(Glibc)
            Glibc.open(path, O_RDONLY)
            #else
            -1
            #endif
        }
        guard descriptor >= 0 else {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Directory could not be opened for synchronization: \(url.lastPathComponent)."
            )
        }
        defer {
            #if canImport(Darwin)
            _ = Darwin.close(descriptor)
            #elseif canImport(Glibc)
            _ = Glibc.close(descriptor)
            #endif
        }

        let result: Int32
        #if canImport(Darwin)
        result = Darwin.fsync(descriptor)
        #elseif canImport(Glibc)
        result = Glibc.fsync(descriptor)
        #else
        result = -1
        #endif
        guard result == 0 else {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Directory synchronization failed: \(url.lastPathComponent)."
            )
        }
        if failurePoint == .afterDirectorySync {
            throw ProjectPersistenceError.atomicReplacementFailed("Injected failure after directory synchronization.")
        }
    }

    package func removeIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ProjectPersistenceError.atomicReplacementFailed(
                "Temporary entry could not be removed: \(url.lastPathComponent)."
            )
        }
    }
}
