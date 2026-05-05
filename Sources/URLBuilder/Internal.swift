import Foundation

/// Encodes Encodable query values to compact JSON strings.
internal enum URLQueryValueEncoder {
    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)

        if let stringValue = try? JSONSerialization.jsonObject(
            with: data,
            options: [.fragmentsAllowed]
        ) as? String {
            return stringValue
        }

        return String(decoding: data, as: UTF8.self)
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
