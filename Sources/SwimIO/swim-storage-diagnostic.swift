import Foundation

public enum SwimStorageCorruptionPolicy:
    Sendable,
    Codable,
    Hashable
{
    case fail
    case skip
}

public struct SwimStorageDiagnostic:
    Sendable,
    Codable,
    Hashable
{
    public let url: URL
    public let message: String

    public init(
        url: URL,
        message: String
    ) {
        self.url = url.standardizedFileURL
        self.message = message
    }
}

public enum SwimStorageError:
    Error,
    Sendable,
    LocalizedError
{
    case corruptedRecord(
        URL,
        message: String
    )

    public var errorDescription: String? {
        switch self {
        case .corruptedRecord(
            let url,
            let message
        ):
            return "Corrupted Swim storage record at \(url.path): \(message)"
        }
    }
}
