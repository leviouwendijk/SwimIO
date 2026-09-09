public struct SwimStorageConfiguration:
    Sendable,
    Codable,
    Hashable
{
    public var maximumStoredBuffers: Int
    public var maximumStoredUndoArchives: Int
    public var maximumUndoEntriesPerArchive: Int

    public init(
        maximumStoredBuffers: Int = 100,
        maximumStoredUndoArchives: Int = 100,
        maximumUndoEntriesPerArchive: Int = 1_000
    ) {
        self.maximumStoredBuffers = max(
            0,
            maximumStoredBuffers
        )
        self.maximumStoredUndoArchives = max(
            0,
            maximumStoredUndoArchives
        )
        self.maximumUndoEntriesPerArchive = max(
            0,
            maximumUndoEntriesPerArchive
        )
    }
}
