import ADJSON

/// Encodes Encodable query values to compact JSON strings.
internal enum URLQueryValueEncoder {
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        // Encode directly to a `JSONValue` (single pass, no encode-then-reparse). A value that
        // encodes to a top-level JSON string (e.g. an `Encodable` enum with a `String` raw value)
        // renders as its unwrapped contents; anything else is serialized as compact JSON with sorted
        // keys and unescaped slashes. The caller still gates the result through the forbidden-IRI
        // scalar check in `URLDeclarationState.queryItems()`.
        let json = try JSONValue(encoding: value)
        if case .string(let stringValue) = json {
            return stringValue
        }
        let bytes = try json.encodedBytes(options: JSONEncodingOptions(keyOrder: .sorted, escapeSlashes: false))
        return String(decoding: bytes, as: UTF8.self)
    }
}

extension String {
    // RFC 3986 §2 + RFC 3987 §4.1 + RFC 9110 §11.7.6 — controls,
    // line/paragraph separators, and bidi formatting controls are not
    // accepted in caller-provided IRI/URI component text.
    internal var containsForbiddenIRIScalar: Bool {
        unicodeScalars.contains { scalar in
            scalar.isForbiddenIRIScalar
        }
    }
}

extension Unicode.Scalar {
    fileprivate var isForbiddenIRIScalar: Bool {
        if properties.generalCategory == .control {
            return true
        }

        switch value {
            case 0x007F,
                0x200E,  // LRM
                0x200F,  // RLM
                0x2028,  // LINE SEPARATOR
                0x2029,  // PARAGRAPH SEPARATOR
                0x202A,  // LRE
                0x202B,  // RLE
                0x202C,  // PDF
                0x202D,  // LRO
                0x202E:  // RLO
                return true
            default:
                return false
        }
    }
}
