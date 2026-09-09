import Foundation

public struct SwimStoredBufferRecord:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var label: String?
    public var content: String
    public var cursorOffset: Int

    public init(
        id: UUID = .init(),
        createdAt: Date = .init(),
        updatedAt: Date = .init(),
        label: String? = nil,
        content: String,
        cursorOffset: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.label = label
        self.content = content
        self.cursorOffset = min(
            max(
                0,
                cursorOffset
            ),
            content.count
        )
    }
}

public struct SwimUndoSnapshot:
    Sendable,
    Codable,
    Hashable
{
    public var text: String
    public var cursorOffset: Int

    public init(
        text: String,
        cursorOffset: Int
    ) {
        self.text = text
        self.cursorOffset = min(
            max(
                0,
                cursorOffset
            ),
            text.count
        )
    }
}

public struct SwimUndoEntry:
    Sendable,
    Codable,
    Hashable,
    Identifiable
{
    public let id: UUID
    public let createdAt: Date
    public let before: SwimUndoSnapshot
    public let after: SwimUndoSnapshot

    public init(
        id: UUID = .init(),
        createdAt: Date = .init(),
        before: SwimUndoSnapshot,
        after: SwimUndoSnapshot
    ) {
        self.id = id
        self.createdAt = createdAt
        self.before = before
        self.after = after
    }
}

public struct SwimUndoArchive:
    Sendable,
    Codable,
    Hashable
{
    public let bufferID: UUID
    public var updatedAt: Date
    public var entries: [SwimUndoEntry]

    /// Number of chronological entries currently applied.
    ///
    /// `0` means every entry is available for redo.
    /// `entries.count` means no redo entries remain.
    public var position: Int

    public init(
        bufferID: UUID,
        updatedAt: Date = .init(),
        entries: [SwimUndoEntry] = [],
        position: Int? = nil
    ) {
        self.bufferID = bufferID
        self.updatedAt = updatedAt
        self.entries = entries
        self.position = min(
            max(
                0,
                position ?? entries.count
            ),
            entries.count
        )
    }

    public func bounded(
        to maximumEntries: Int
    ) -> Self {
        let maximumEntries = max(
            0,
            maximumEntries
        )

        guard entries.count > maximumEntries else {
            return .init(
                bufferID: bufferID,
                updatedAt: updatedAt,
                entries: entries,
                position: position
            )
        }

        let removedCount =
            entries.count - maximumEntries
        let retained = Array(
            entries.dropFirst(
                removedCount
            )
        )

        return .init(
            bufferID: bufferID,
            updatedAt: updatedAt,
            entries: retained,
            position: max(
                0,
                position - removedCount
            )
        )
    }
}

public struct SwimStoredBufferListing:
    Sendable,
    Codable,
    Hashable
{
    public let records: [SwimStoredBufferRecord]
    public let diagnostics: [SwimStorageDiagnostic]

    public init(
        records: [SwimStoredBufferRecord],
        diagnostics: [SwimStorageDiagnostic] = []
    ) {
        self.records = records
        self.diagnostics = diagnostics
    }
}

public struct SwimUndoArchiveListing:
    Sendable,
    Codable,
    Hashable
{
    public let archives: [SwimUndoArchive]
    public let diagnostics: [SwimStorageDiagnostic]

    public init(
        archives: [SwimUndoArchive],
        diagnostics: [SwimStorageDiagnostic] = []
    ) {
        self.archives = archives
        self.diagnostics = diagnostics
    }
}
