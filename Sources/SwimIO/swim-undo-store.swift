import Foundation
import IO

public struct SwimUndoStore: Sendable {
    public let layout: SwimStorageLayout
    public let configuration: SwimStorageConfiguration
    public let fileSystem: FileSystem

    public init(
        layout: SwimStorageLayout = .default,
        configuration: SwimStorageConfiguration = .init(),
        fileSystem: FileSystem = .default
    ) {
        self.layout = layout
        self.configuration = configuration
        self.fileSystem = fileSystem
    }

    @discardableResult
    public func store(
        _ archive: SwimUndoArchive
    ) throws -> [UUID] {
        try layout.prepare(
            fileSystem: fileSystem
        )

        _ = try list(
            corruptionPolicy: .fail
        )

        let bounded = archive.bounded(
            to: configuration.maximumUndoEntriesPerArchive
        )

        try SwimStorageCodec.write(
            bounded,
            to: layout.undoArchiveURL(
                for: bounded.bufferID
            )
        )

        return try prune()
    }

    public func load(
        bufferID: UUID
    ) throws -> SwimUndoArchive? {
        let url = layout.undoArchiveURL(
            for: bufferID
        )

        guard fileSystem.exists(
            url
        ) else {
            return nil
        }

        return try decode(
            url
        )
    }

    public func list(
        corruptionPolicy: SwimStorageCorruptionPolicy = .fail
    ) throws -> SwimUndoArchiveListing {
        try layout.prepare(
            fileSystem: fileSystem
        )

        let urls = try fileSystem.directory.contents(
            layout.undoURL
        ).filter {
            $0.pathExtension == "json"
        }.sorted {
            $0.path < $1.path
        }

        var archives: [SwimUndoArchive] = []
        var diagnostics: [SwimStorageDiagnostic] = []

        for url in urls {
            do {
                archives.append(
                    try decode(
                        url
                    )
                )
            } catch {
                switch corruptionPolicy {
                case .fail:
                    throw error

                case .skip:
                    diagnostics.append(
                        .init(
                            url: url,
                            message: error.localizedDescription
                        )
                    )
                }
            }
        }

        archives.sort(
            by: newestFirst
        )

        return .init(
            archives: archives,
            diagnostics: diagnostics
        )
    }

    public func remove(
        bufferID: UUID
    ) throws {
        let url = layout.undoArchiveURL(
            for: bufferID
        )

        guard fileSystem.exists(
            url
        ) else {
            return
        }

        try fileSystem.remove(
            url
        )
    }

    @discardableResult
    public func prune(
        corruptionPolicy: SwimStorageCorruptionPolicy = .fail
    ) throws -> [UUID] {
        let listing = try list(
            corruptionPolicy: corruptionPolicy
        )
        let overflow = max(
            0,
            listing.archives.count
                - configuration.maximumStoredUndoArchives
        )

        guard overflow > 0 else {
            return []
        }

        let evicted = listing.archives.sorted(
            by: oldestFirst
        ).prefix(
            overflow
        )

        for archive in evicted {
            try remove(
                bufferID: archive.bufferID
            )
        }

        return evicted.map(\.bufferID)
    }

    private func decode(
        _ url: URL
    ) throws -> SwimUndoArchive {
        do {
            return try SwimStorageCodec.read(
                SwimUndoArchive.self,
                from: url
            )
        } catch {
            throw SwimStorageError.corruptedRecord(
                url,
                message: error.localizedDescription
            )
        }
    }

    private func newestFirst(
        _ lhs: SwimUndoArchive,
        _ rhs: SwimUndoArchive
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.bufferID.uuidString.lowercased()
            < rhs.bufferID.uuidString.lowercased()
    }

    private func oldestFirst(
        _ lhs: SwimUndoArchive,
        _ rhs: SwimUndoArchive
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }

        return lhs.bufferID.uuidString.lowercased()
            < rhs.bufferID.uuidString.lowercased()
    }
}
