import Foundation

/// One column value on its way to or from a `money_*` table.
///
/// A closed set rather than `Any`: rows cross an actor boundary between the
/// network and the store, so they have to be `Sendable`, and a closed set also
/// means a fingerprint of a row is deterministic. There is deliberately no
/// floating-point case — money travels as a decimal *string* (the pull asks
/// PostgREST to cast numeric columns to text), so a figure can never pass
/// through a `Double` and come back a cent out.
public enum SyncValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int64)
    case string(String)
    case strings([String])

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int64? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var isNull: Bool { self == .null }
}

/// A row as a flat dictionary of column name to value.
public typealias SyncRow = [String: SyncValue]

extension SyncValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        // Order matters: JSONDecoder only yields a Bool for `true`/`false`, and
        // only an Int64 for a literal with no fraction, so each probe is exact.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String].self) {
            self = .strings(value)
        } else if let value = try? container.decode(Decimal.self) {
            // Only reached if a numeric column was selected without a text
            // cast. Kept as its decimal text so it is still usable, but the
            // select lists in `SyncTable` are what make this path unused.
            self = .string(SyncFormat.decimalString(value))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported value in a synced row"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .strings(let value): try container.encode(value)
        }
    }
}

public enum SyncJSON {
    /// Decodes a PostgREST response body: a JSON array of row objects.
    public static func rows(from data: Data) throws -> [SyncRow] {
        try JSONDecoder().decode([SyncRow].self, from: data)
    }

    /// Encodes rows for an upsert body.
    public static func data(for rows: [SyncRow]) throws -> Data {
        try encoder.encode(rows)
    }

    /// A stable text form of a row, for noticing that it changed since it was
    /// last pushed or pulled. Keys are sorted, so two equal rows always give the
    /// same fingerprint however the dictionary happens to be ordered.
    public static func fingerprint(of row: SyncRow) -> String {
        guard let data = try? encoder.encode(row) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
