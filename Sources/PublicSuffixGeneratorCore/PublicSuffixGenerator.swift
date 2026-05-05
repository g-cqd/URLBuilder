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

    /// Parses the IANA TLD list. The first line is the upstream version
    /// comment; subsequent single-token lines are the TLD labels.
    public static func parseIANA(_ source: String) -> IANACatalogue {
        var version = ""
        var tlds: Set<String> = []
        for (index, line) in source.split(
            omittingEmptySubsequences: false, whereSeparator: \.isNewline
        ).enumerated() {
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

    // MARK: - Emission

    /// Emits the final Swift source.
    public static func emit(iana: IANACatalogue, psl: PSLCatalogue) -> String {
        var out = ""
        out.reserveCapacity(1 << 18)

        out += """
            // =====================================================================
            // PublicSuffix — generated by PublicSuffixGeneratorPlugin — DO NOT EDIT.
            //
            // Sources:
            //   IANA Root Zone Database  — \(iana.version)
            //   Mozilla PSL (ICANN only) — \(psl.version)
            //                              \(psl.commit)
            //
            // Counts:
            //   IANA single-label TLDs    = \(iana.tlds.count)
            //   PSL ICANN literal suffixes = \(psl.suffixes.count)
            //   PSL ICANN wildcard rules   = \(psl.wildcardParents.count)
            //   PSL ICANN exceptions       = \(psl.exceptions.count)
            // =====================================================================

            import Foundation

            extension TopLevelDomain {

            """

        for tld in iana.tlds {
            let identifier = swiftIdentifier(for: tld)
            out +=
                "  public static let \(identifier) = TopLevelDomain(\"\(swiftStringLiteral(tld))\")\n"
        }

        out += """
            }

            /// Public-suffix catalog sourced from IANA + the ICANN section of the
            /// Mozilla Public Suffix List. The catalog is purely informational: the
            /// DSL never auto-rejects an unknown suffix. Callers who want strict
            /// rejection MUST consult `PublicSuffix.contains(_:)` themselves.
            public enum PublicSuffix {

              /// IANA Root Zone single-label TLDs.
              public static let icannTLDs: Set<String> = [

            """

        for tld in iana.tlds {
            out += "    \"\(swiftStringLiteral(tld))\",\n"
        }

        out += """
              ]

              /// Literal ICANN section rules from the Mozilla Public Suffix List.
              public static let icannSuffixes: Set<String> = [

            """

        for suffix in psl.suffixes {
            out += "    \"\(swiftStringLiteral(suffix))\",\n"
        }

        out += """
              ]

              /// Wildcard-rule parents from the ICANN section of the Mozilla
              /// Public Suffix List. A parent here means every direct child is
              /// a public suffix, while the parent itself is not.
              public static let icannWildcardParents: Set<String> = [

            """

        for suffix in psl.wildcardParents {
            out += "    \"\(swiftStringLiteral(suffix))\",\n"
        }

        out += """
              ]

              /// Exception rules from the ICANN section of the Mozilla Public
              /// Suffix List. These entries are explicitly not public suffixes;
              /// their parent suffix is the prevailing rule.
              public static let icannExceptions: Set<String> = [

            """

        for suffix in psl.exceptions {
            out += "    \"\(swiftStringLiteral(suffix))\",\n"
        }

        out += """
              ]

              /// Returns true if `suffix` is a known public suffix.
              public static func contains(_ suffix: String) -> Bool {
                guard let normalized = normalizedDomain(suffix) else { return false }
                if icannExceptions.contains(normalized) { return false }
                if icannSuffixes.contains(normalized) { return true }

                let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
                guard labels.count > 1 else { return false }
                let parent = labels.dropFirst().joined(separator: ".")
                return icannWildcardParents.contains(parent)
              }

              /// Returns the longest public suffix that matches a trailing portion
              /// of `host` using the PSL matching algorithm's literal, wildcard,
              /// and exception rule precedence.
              public static func longestMatch(for host: String) -> String? {
                guard let normalized = normalizedDomain(host) else { return nil }
                let labels = normalized.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

                for index in labels.indices {
                  let candidate = labels[index...].joined(separator: ".")
                  if icannExceptions.contains(candidate) {
                    let suffixLabels = labels[labels.index(after: index)...]
                    guard suffixLabels.isEmpty == false else { return nil }
                    return suffixLabels.joined(separator: ".")
                  }
                }

                var best: String?
                for index in labels.indices {
                  let candidate = labels[index...].joined(separator: ".")
                  if icannSuffixes.contains(candidate), isLonger(candidate, than: best) {
                    best = candidate
                  }
                  let nextIndex = labels.index(after: index)
                  if nextIndex < labels.endIndex {
                    let wildcardParent = labels[nextIndex...].joined(separator: ".")
                    if icannWildcardParents.contains(wildcardParent), isLonger(candidate, than: best) {
                      best = candidate
                    }
                  }
                }
                return best
              }

              private static func isLonger(_ candidate: String, than current: String?) -> Bool {
                guard let current else { return true }
                return candidate.split(separator: ".").count > current.split(separator: ".").count
              }

              private static func normalizedDomain(_ value: String) -> String? {
                let lowercased = value.lowercased()
                guard lowercased.isEmpty == false, lowercased.hasAllowedDomainScalars else {
                  return nil
                }
                guard
                  let url = URL(string: "https://\\(lowercased)"),
                  let host = url.host(percentEncoded: false)?.lowercased(),
                  host.isValidA_LABELDomain
                else {
                  return nil
                }
                return host
              }
            }

            private extension String {
              var hasAllowedDomainScalars: Bool {
                unicodeScalars.allSatisfy { scalar in
                  if scalar.value < 0x80 {
                    return (65...90).contains(scalar.value)
                      || (97...122).contains(scalar.value)
                      || (48...57).contains(scalar.value)
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

              var isValidA_LABELDomain: Bool {
                guard allSatisfy({ character in
                  character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == ".")
                }) else {
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

            """

        return out
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
        "Any", "Self",
    ]

    private static func canonicalIANAEntry(_ rawValue: String) -> String? {
        let lowercased = rawValue.lowercased()
        guard lowercased.isEmpty == false, lowercased.allSatisfy(\.isLDHLabelCharacter) else {
            return nil
        }
        return lowercased
    }

    private static func canonicalPSLEntry(_ rawValue: String) -> String? {
        let lowercased = rawValue.lowercased()
        guard lowercased.isEmpty == false, lowercased.hasAllowedDomainScalars else {
            return nil
        }
        guard
            let url = URL(string: "https://\(lowercased)"),
            let host = url.host(percentEncoded: false)?.lowercased(),
            host.isValidA_LABELDomain
        else {
            return nil
        }
        return host
    }

    private static func swiftStringLiteral(_ value: String) -> String {
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
                return (65...90).contains(scalar.value)
                    || (97...122).contains(scalar.value)
                    || (48...57).contains(scalar.value)
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
