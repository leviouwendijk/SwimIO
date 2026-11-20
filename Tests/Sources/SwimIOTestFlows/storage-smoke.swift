import Foundation
import IO
import SwimIO
import Writers

enum SwimStorageSmoke {
    struct Failure:
        Error,
        CustomStringConvertible
    {
        let message: String

        var description: String {
            message
        }
    }

    static func run() throws {
        try runBufferRetentionProbe()
        try runStableTieBreakProbe()
        try runCorruptionProbe()
        try runUndoProbe()
    }

    private static func runBufferRetentionProbe() throws {
        let root = temporaryRoot(
            "buffers"
        )
        defer {
            try? FileSystem.default.remove(
                root
            )
        }

        let layout = SwimStorageLayout(
            rootURL: root
        )
        let store = SwimBufferStore(
            layout: layout,
            configuration: .init(
                maximumStoredBuffers: 3
            )
        )
        let ids = [
            uuid(1),
            uuid(2),
            uuid(3),
            uuid(4),
        ]

        for index in 0..<4 {
            let date = Date(
                timeIntervalSince1970: TimeInterval(
                    index + 1
                )
            )

            _ = try store.store(
                .init(
                    id: ids[index],
                    createdAt: date,
                    updatedAt: date,
                    content: "buffer-\(index + 1)",
                    cursorOffset: index
                )
            )
        }

        let listing = try store.list()

        try expect(
            listing.records.map(\.id)
                == [
                    ids[3],
                    ids[2],
                    ids[1],
                ],
            "buffer retention should evict exactly the oldest record"
        )
        try expect(
            try store.load(
                ids[0]
            ) == nil,
            "evicted buffer should no longer load"
        )

        let restarted = SwimBufferStore(
            layout: layout,
            configuration: .init(
                maximumStoredBuffers: 3
            )
        )

        try expect(
            try restarted.list().records.map(\.id)
                == listing.records.map(\.id),
            "buffer ordering should survive store reconstruction"
        )

        let newest = try restarted.restoreNewest(
            limit: 2
        )

        try expect(
            newest.records.map(\.id)
                == [
                    ids[3],
                    ids[2],
                ],
            "restoreNewest should retain newest-first ordering"
        )
    }

    private static func runStableTieBreakProbe() throws {
        let root = temporaryRoot(
            "tie-break"
        )
        defer {
            try? FileSystem.default.remove(
                root
            )
        }

        let store = SwimBufferStore(
            layout: .init(
                rootURL: root
            ),
            configuration: .init(
                maximumStoredBuffers: 2
            )
        )
        let date = Date(
            timeIntervalSince1970: 100
        )
        let ids = [
            uuid(1),
            uuid(2),
            uuid(3),
        ]

        for id in ids {
            _ = try store.store(
                .init(
                    id: id,
                    createdAt: date,
                    updatedAt: date,
                    content: id.uuidString
                )
            )
        }

        let retained = try store.list().records.map(\.id)

        try expect(
            retained == [
                ids[1],
                ids[2],
            ],
            "equal timestamps should evict the lexicographically smallest stable identifier"
        )
    }

    private static func runCorruptionProbe() throws {
        let root = temporaryRoot(
            "corruption"
        )
        defer {
            try? FileSystem.default.remove(
                root
            )
        }

        let layout = SwimStorageLayout(
            rootURL: root
        )
        let store = SwimBufferStore(
            layout: layout,
            configuration: .init(
                maximumStoredBuffers: 3
            )
        )

        try layout.prepare()

        let corruptID = uuid(99)
        _ = try StandardWriter(
            layout.bufferRecordURL(
                for: corruptID
            )
        ).write(
            "{ definitely-not-json",
            options: .overwriteWithoutBackup
        )

        do {
            _ = try store.list()
            throw Failure(
                message: "default corruption policy should fail explicitly"
            )
        } catch SwimStorageError.corruptedRecord {
        }

        let skipped = try store.list(
            corruptionPolicy: .skip
        )

        try expect(
            skipped.records.isEmpty,
            "skip policy should exclude corrupted records"
        )
        try expect(
            skipped.diagnostics.count == 1,
            "skip policy should surface one explicit corruption diagnostic"
        )
    }

    private static func runUndoProbe() throws {
        let root = temporaryRoot(
            "undo"
        )
        defer {
            try? FileSystem.default.remove(
                root
            )
        }

        let layout = SwimStorageLayout(
            rootURL: root
        )
        let store = SwimUndoStore(
            layout: layout,
            configuration: .init(
                maximumStoredBuffers: 10,
                maximumStoredUndoArchives: 2,
                maximumUndoEntriesPerArchive: 2
            )
        )
        let bufferID = uuid(10)
        let entries = [
            entry(
                id: uuid(21),
                before: "a",
                after: "ab"
            ),
            entry(
                id: uuid(22),
                before: "ab",
                after: "abc"
            ),
            entry(
                id: uuid(23),
                before: "abc",
                after: "abcd"
            ),
        ]

        _ = try store.store(
            .init(
                bufferID: bufferID,
                updatedAt: Date(
                    timeIntervalSince1970: 1
                ),
                entries: entries,
                position: 3
            )
        )

        guard let restored = try store.load(
            bufferID: bufferID
        ) else {
            throw Failure(
                message: "stored undo archive should load"
            )
        }

        try expect(
            restored.entries.map(\.id)
                == [
                    uuid(22),
                    uuid(23),
                ],
            "undo archive should retain its newest bounded entries"
        )
        try expect(
            restored.position == 2,
            "undo position should shift when oldest entries are pruned"
        )

        _ = try store.store(
            .init(
                bufferID: uuid(11),
                updatedAt: Date(
                    timeIntervalSince1970: 2
                )
            )
        )
        _ = try store.store(
            .init(
                bufferID: uuid(12),
                updatedAt: Date(
                    timeIntervalSince1970: 3
                )
            )
        )

        let archives = try store.list().archives

        try expect(
            archives.map(\.bufferID)
                == [
                    uuid(12),
                    uuid(11),
                ],
            "undo archive retention should deterministically evict the oldest archive"
        )
        try expect(
            try store.load(
                bufferID: bufferID
            ) == nil,
            "evicted undo archive should no longer load"
        )
    }

    private static func entry(
        id: UUID,
        before: String,
        after: String
    ) -> SwimUndoEntry {
        .init(
            id: id,
            createdAt: Date(
                timeIntervalSince1970: 1
            ),
            before: .init(
                text: before,
                cursorOffset: before.count
            ),
            after: .init(
                text: after,
                cursorOffset: after.count
            )
        )
    }

    private static func temporaryRoot(
        _ name: String
    ) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "swimiotest-\(name)-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
    }

    private static func uuid(
        _ value: Int
    ) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                value
            )
        )!
    }

    private static func expect(
        _ condition: @autoclosure () throws -> Bool,
        _ message: String
    ) throws {
        guard try condition() else {
            throw Failure(
                message: message
            )
        }
    }
}
