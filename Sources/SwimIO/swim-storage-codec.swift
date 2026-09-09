import Foundation
import Writers

enum SwimStorageCodec {
    static func write<Value: Encodable>(
        _ value: Value,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]

        let data = try encoder.encode(
            value
        )
        let text = String(
            decoding: data,
            as: UTF8.self
        )

        _ = try StandardWriter(
            url
        ).write(
            text,
            options: .overwriteWithoutBackup
        )
    }

    static func read<Value: Decodable>(
        _ type: Value.Type,
        from url: URL
    ) throws -> Value {
        let text = try IntegratedReader.text(
            at: url,
            encoding: .utf8,
            missingFileReturnsEmpty: false
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(
            type,
            from: Data(
                text.utf8
            )
        )
    }
}
