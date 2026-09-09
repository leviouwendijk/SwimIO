import Foundation
import IO
import Path

public struct SwimStorageLayout:
    Sendable,
    Hashable
{
    public let rootURL: URL
    public let buffersURL: URL
    public let undoURL: URL

    public init(
        rootURL: URL
    ) {
        let rootURL = rootURL.standardizedFileURL

        self.rootURL = rootURL
        buffersURL = rootURL.appendingPathComponent(
            "buffers",
            isDirectory: true
        )
        undoURL = rootURL.appendingPathComponent(
            "undo",
            isDirectory: true
        )
    }

    public static var `default`: Self {
        .init(
            rootURL: StandardPath.home.directory_url
                .appendingPathComponent(
                    ".swim",
                    isDirectory: true
                )
        )
    }

    public func bufferRecordURL(
        for id: UUID
    ) -> URL {
        buffersURL.appendingPathComponent(
            id.uuidString.lowercased() + ".json",
            isDirectory: false
        )
    }

    public func undoArchiveURL(
        for bufferID: UUID
    ) -> URL {
        undoURL.appendingPathComponent(
            bufferID.uuidString.lowercased() + ".json",
            isDirectory: false
        )
    }

    public func prepare(
        fileSystem: FileSystem = .default
    ) throws {
        try fileSystem.directory.create(
            rootURL
        )
        try fileSystem.directory.create(
            buffersURL
        )
        try fileSystem.directory.create(
            undoURL
        )
    }
}
