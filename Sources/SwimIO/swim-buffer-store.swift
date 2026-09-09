import Foundation
import IO

public struct SwimBufferStore: Sendable {
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
        _ record: SwimStoredBufferRecord
    ) throws -> [UUID] {
        try layout.prepare(
            fileSystem: fileSystem
        )

        _ = try list(
            corruptionPolicy: .fail
        )

        try SwimStorageCodec.write(
            record,
            to: layout.bufferRecordURL(
                for: record.id
            )
        )

        return try prune()
    }

    public func load(
        _ id: UUID
    ) throws -> SwimStoredBufferRecord? {
        let url = layout.bufferRecordURL(
            for: id
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
    ) throws -> SwimStoredBufferListing {
        try layout.prepare(
            fileSystem: fileSystem
        )

        let urls = try fileSystem.directory.contents(
            layout.buffersURL
        ).filter {
            $0.pathExtension == "json"
        }.sorted {
            $0.path < $1.path
        }

        var records: [SwimStoredBufferRecord] = []
        var diagnostics: [SwimStorageDiagnostic] = []

        for url in urls {
            do {
                records.append(
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

        records.sort(
            by: newestFirst
        )

        return .init(
            records: records,
            diagnostics: diagnostics
        )
    }

    public func restoreNewest(
        limit rawLimit: Int,
        corruptionPolicy: SwimStorageCorruptionPolicy = .fail
    ) throws -> SwimStoredBufferListing {
        let listing = try list(
            corruptionPolicy: corruptionPolicy
        )
        let limit = max(
            0,
            rawLimit
        )

        return .init(
            records: Array(
                listing.records.prefix(
                    limit
                )
            ),
            diagnostics: listing.diagnostics
        )
    }

    public func remove(
        _ id: UUID
    ) throws {
        let url = layout.bufferRecordURL(
            for: id
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
            listing.records.count
                - configuration.maximumStoredBuffers
        )

        guard overflow > 0 else {
            return []
        }

        let evicted = listing.records.sorted(
            by: oldestFirst
        ).prefix(
            overflow
        )

        for record in evicted {
            try remove(
                record.id
            )
        }

        return evicted.map(\.id)
    }

    private func decode(
        _ url: URL
    ) throws -> SwimStoredBufferRecord {
        do {
            return try SwimStorageCodec.read(
                SwimStoredBufferRecord.self,
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
        _ lhs: SwimStoredBufferRecord,
        _ rhs: SwimStoredBufferRecord
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        return lhs.id.uuidString.lowercased()
            < rhs.id.uuidString.lowercased()
    }

    private func oldestFirst(
        _ lhs: SwimStoredBufferRecord,
        _ rhs: SwimStoredBufferRecord
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }

        return lhs.id.uuidString.lowercased()
            < rhs.id.uuidString.lowercased()
    }
}
