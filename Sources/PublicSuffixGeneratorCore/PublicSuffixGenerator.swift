import Foundation

/// Generates `PublicSuffix.swift` from the IANA Root Zone Database and
/// the ICANN section of the Mozilla Public Suffix List.
///
/// The generator is pure: it takes the source texts as input and
/// returns the Swift source that would have been written to disk. The
/// CLI wrapper and the build tool plugin are thin shells around this
/// type so the parsing and emission rules can be exercised by tests.
public enum PublicSuffixGenerator {
    /// Generates the full Swift source for the given upstream files.
    public static func generate(ianaSource: String, pslSource: String) -> String {
        let iana = parseIANA(ianaSource)
        let psl = parsePSL(pslSource)
        return emit(iana: iana, psl: psl)
    }

    // MARK: - Parsing

    /// Parsed IANA Root Zone Database.
    public struct IANACatalogue: Sendable, Equatable {
        public let version: String
        public let tlds: [String]
    }

    /// Parsed Mozilla Public Suffix List (ICANN section only).
    public struct PSLCatalogue: Sendable, Equatable {
        public let version: String
        public let commit: String
        public let suffixes: [String]
        public let wildcardParents: [String]
        public let exceptions: [String]
    }

    /// Parses the IANA TLD list.
    ///
    /// The first line is the upstream version
    /// comment; subsequent single-token lines are the TLD labels.
    public static func parseIANA(_ source: String) -> IANACatalogue {
        var version = ""
        var tlds: Set<String> = []
        for (index, line)
            in source.split(
                omittingEmptySubsequences: false, whereSeparator: \.isNewline
            )
            .enumerated()
        {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if index == 0 {
                version =
                    trimmed.hasPrefix("#")
                    ? trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    : trimmed
                continue
            }
            guard !trimmed.isEmpty,
                trimmed.hasPrefix("#") == false,
                let tld = canonicalIANAEntry(trimmed)
            else { continue }
            tlds.insert(tld)
        }
        return IANACatalogue(version: version, tlds: tlds.sortedByUTF8())
    }

    /// Parses the ICANN section of the Mozilla Public Suffix List.
    ///
    /// Wildcard prefixes (`*.`) and exception markers (`!`) are tracked
    /// separately because PSL matching gives them different semantics.
    public static func parsePSL(_ source: String) -> PSLCatalogue {
        var version = ""
        var commit = ""
        var inICANN = false
        var suffixes: Set<String> = []
        var wildcardParents: Set<String> = []
        var exceptions: Set<String> = []

        for line in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let raw = String(line)
            let stripped = raw.trimmingCharacters(in: .whitespaces)

            if version.isEmpty, let parsed = Self.headerValue(line: stripped, key: "VERSION:") {
                version = parsed
            }
            if commit.isEmpty, let parsed = Self.headerValue(line: stripped, key: "COMMIT:") {
                commit = parsed
            }
            if stripped.hasPrefix("// ===BEGIN ICANN DOMAINS===") {
                inICANN = true
                continue
            }
            if stripped.hasPrefix("// ===END ICANN DOMAINS===") {
                inICANN = false
                continue
            }
            guard inICANN, !stripped.isEmpty, !stripped.hasPrefix("//") else { continue }

            var entry = stripped
            let isException = entry.hasPrefix("!")
            if isException { entry.removeFirst() }
            let isWildcard = entry.hasPrefix("*.")
            if isWildcard { entry.removeFirst(2) }

            guard let canonicalEntry = canonicalPSLEntry(entry) else { continue }
            if isException {
                exceptions.insert(canonicalEntry)
            } else if isWildcard {
                wildcardParents.insert(canonicalEntry)
            } else {
                suffixes.insert(canonicalEntry)
            }
        }

        return PSLCatalogue(
            version: version,
            commit: commit,
            suffixes: suffixes.sortedByUTF8(),
            wildcardParents: wildcardParents.sortedByUTF8(),
            exceptions: exceptions.sortedByUTF8()
        )
    }

    /// Extracts the value of a header line of the form `// KEY: value`.
    static func headerValue(line: String, key: String) -> String? {
        guard line.hasPrefix("//") else { return nil }
        let body = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        guard body.hasPrefix(key) else { return nil }
        return body.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Identifier rules

    /// Translates a TLD label into a Swift identifier:
    /// hyphens become underscores, leading-digit names get a leading
    /// underscore, and Swift keywords are backtick-escaped.
    public static func swiftIdentifier(for tld: String) -> String {
        precondition(canonicalIANAEntry(tld) != nil, "TLD labels must be LDH/A-label tokens")
        var identifier = tld.lowercased().replacingOccurrences(of: "-", with: "_")
        if let first = identifier.first, first.isASCII, first.isNumber {
            identifier = "_" + identifier
        }
        return Self.swiftKeywords.contains(identifier)
            ? "`\(identifier)`"
            : identifier
    }

    /// Swift reserved words that could collide with TLD identifiers.
    static let swiftKeywords: Set<String> = [
        "as", "associatedtype", "break", "case", "catch", "class", "continue",
        "default", "defer", "deinit", "do", "else", "enum", "extension",
        "fallthrough", "false", "fileprivate", "for", "func", "guard", "if",
        "import", "in", "init", "inout", "internal", "is", "let", "nil",
        "operator", "private", "protocol", "public", "repeat", "rethrows",
        "return", "self", "static", "struct", "subscript", "super", "switch",
        "throw", "throws", "true", "try", "typealias", "var", "where", "while",
        "Any", "Self"
    ]

    private static func canonicalIANAEntry(_ rawValue: String) -> String? {
        let lowercased = rawValue.lowercased()
        guard lowercased.isEmpty == false, lowercased.allSatisfy(\.isLDHLabelCharacter) else {
            return nil
        }
        return lowercased
    }

    private static func canonicalPSLEntry(_ rawValue: String) -> String? {
        normalizedDomain(rawValue)
    }

    /// The generator-side domain normalizer.
    ///
    /// Kept in lockstep with the emitted `PublicSuffix.normalizedDomain`; the
    /// emitted copy of the `String` helpers it relies on is single-sourced from
    /// `domainHelpersSource`, and the agreement is verified by
    /// `DomainNormalizerParityTests`.
    static func normalizedDomain(_ value: String) -> String? {
        let lowercased = value.lowercased()
        guard lowercased.isEmpty == false, lowercased.hasAllowedDomainScalars else {
            return nil
        }
        // Deliberately the lenient `URL(string:)`, NOT
        // `URL(string:encodingInvalidCharacters: false)`: only the lenient
        // initializer runs Foundation's IDNA, converting a U-label suffix to its
        // A-label. `isValidA_LABELDomain` then re-checks the result is ASCII LDH.
        guard
            let url = URL(string: "https://\(lowercased)"),
            let host = url.host(percentEncoded: false)?.lowercased(),
            host.isValidA_LABELDomain
        else {
            return nil
        }
        return host
    }

    static func swiftStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

// MARK: - Helpers

extension Set where Element == String {
    /// Sort by raw UTF-8 byte order, mirroring `LC_ALL=C sort -u`.
    fileprivate func sortedByUTF8() -> [String] {
        sorted { lhs, rhs in
            lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
        }
    }
}

extension String {
    fileprivate var hasAllowedDomainScalars: Bool {
        unicodeScalars.allSatisfy { scalar in
            if scalar.value < 0x80 {
                return (65 ... 90).contains(scalar.value)
                    || (97 ... 122).contains(scalar.value)
                    || (48 ... 57).contains(scalar.value)
                    || scalar.value == 45
                    || scalar.value == 46
            }
            switch scalar.properties.generalCategory {
                case .lowercaseLetter, .uppercaseLetter, .titlecaseLetter, .modifierLetter,
                    .otherLetter, .decimalNumber, .letterNumber, .nonspacingMark, .spacingMark:
                    return true
                default:
                    return false
            }
        }
    }

    // swift-format-ignore: AlwaysUseLowerCamelCase
    fileprivate var isValidA_LABELDomain: Bool {
        guard
            allSatisfy({ character in
                character.isASCII
                    && (character.isLetter || character.isNumber || character == "-"
                        || character == ".")
            })
        else {
            return false
        }
        return split(separator: ".", omittingEmptySubsequences: false)
            .allSatisfy { label in
                label.isEmpty == false
                    && label.first != "-"
                    && label.last != "-"
            }
    }
}

extension Character {
    fileprivate var isLDHLabelCharacter: Bool {
        isASCII && (isLetter || isNumber || self == "-")
    }
}
