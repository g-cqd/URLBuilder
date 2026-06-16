import ADJSON

/// Encodes Encodable query values to compact JSON strings.
internal enum URLQueryValueEncoder {
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        var encoder = ADJSON.JSONEncoder()
        encoder.options = JSONEncodingOptions(keyOrder: .sorted, escapeSlashes: false)
        let bytes = try encoder.encodeToBytes(value)

        // A value that encodes to a top-level JSON string (e.g. an `Encodable` enum with a
        // `String` raw value) renders as its unwrapped contents, not the quoted/escaped JSON
        // literal — matching the prior `JSONSerialization`-based behavior, but via ADJSON's
        // value model so the query path stays Foundation-encoder-free.
        //
        // This is an encode-then-reparse double pass purely to detect that top-level string.
        // ADJSON exposes no `encodeToValue`; if it gains one, encode straight to a `JSONValue`
        // and drop the reparse. The `try?` is NOT fail-open: a parse failure (which cannot
        // happen for ADJSON's own just-emitted output) deliberately falls through to the
        // already-encoded JSON bytes, which the caller still gates through the forbidden-IRI
        // scalar check in `URLDeclarationState.queryItems()`. Do not turn it into a `throw`
        // or an unchecked early return.
        if let document = try? ADJSON.parse(bytes),
            case .string(let stringValue) = JSONValue(document.root)
        {
            return stringValue
        }

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

extension Character {
    internal var isASCIIAlpha: Bool {
        ("a"..."z").contains(self) || ("A"..."Z").contains(self)
    }

    internal var isASCIIDigit: Bool {
        ("0"..."9").contains(self)
    }

    internal var isASCIIAlphanumeric: Bool {
        isASCIIAlpha || isASCIIDigit
    }

    internal var isASCIIHexDigit: Bool {
        isASCIIDigit || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }

    internal var isSubDelimiter: Bool {
        switch self {
            case "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "=":
                true
            default:
                false
        }
    }
}
