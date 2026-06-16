import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

internal enum URLValidator {
    static func normalizedScheme(_ rawValue: String) throws(URLBuildError) -> String {
        let scheme = rawValue.lowercased()

        guard scheme.first?.isASCIIAlpha == true else {
            throw .invalidScheme(rawValue)
        }

        guard
            scheme.allSatisfy({ character in
                character.isASCIIAlpha || character.isASCIIDigit || character == "+"
                    || character == "-"
                    || character == "."
            })
        else {
            throw .invalidScheme(rawValue)
        }

        return scheme
    }

    static func validatedHostName(_ rawHost: String) throws(URLBuildError) -> String {
        let trimmedHost = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedHost == rawHost, trimmedHost.isEmpty == false else {
            throw .invalidHost(rawHost)
        }

        if trimmedHost.hasPrefix("[") || trimmedHost.hasSuffix("]") || trimmedHost.contains(":") {
            throw .invalidHost(rawHost)
        }

        guard trimmedHost.contains(where: \.isHostDelimiter) == false else {
            throw .invalidHost(rawHost)
        }

        // RFC 5892 §2.4 — reject DISALLOWED codepoints (emoji symbols,
        // punctuation, non-characters, controls) BEFORE handing to Foundation,
        // because Foundation's IDNA implementation Punycode-encodes some
        // DISALLOWED scalars instead of rejecting them.
        try rejectDISALLOWEDCodepoints(in: rawHost)

        // Deliberately the lenient `URL(string:)`, NOT
        // `URL(string:encodingInvalidCharacters: false)`: only the lenient
        // initializer runs Foundation's IDNA, converting a U-label host
        // (`münchen.de`) to its A-label (`xn--mnchen-3ya.de`) per RFC 5891. The
        // strict initializer disables that conversion and would reject every
        // internationalized domain. This boundary stays fenced by the RFC 5892
        // pre-filter above and the per-label ASCII-LDH re-validation below.
        guard
            let url = URL(string: "https://\(rawHost)"),
            let host = url.host(percentEncoded: false)?.lowercased()
        else {
            throw .invalidHost(rawHost)
        }

        // DNS names are limited to 255 octets including the implicit root
        // dot, leaving at most 253 octets in the textual host form.
        guard host.utf8.count <= 253 else {
            throw .invalidHost(rawHost)
        }

        var labels = host.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard labels.isEmpty == false else {
            throw .invalidHost(rawHost)
        }

        if labels.last == "" {
            guard labels.count > 1 else {
                throw .invalidHost(rawHost)
            }
            labels.removeLast()
        }

        for label in labels {
            try validatedHostLabel(label)
        }

        if isInvalidIPv4Literal(host) {
            throw .invalidHost(rawHost)
        }

        return host
    }

    static func validatedIPv6Address(_ rawAddress: String) throws(URLBuildError) -> String {
        guard let address = unbracketedLiteral(rawAddress) else {
            throw .invalidIPv6Address(rawAddress)
        }
        guard let normalizedAddress = normalizedIPv6Address(address) else {
            throw .invalidIPv6Address(rawAddress)
        }

        // Final structural acceptance via the same lenient `URL(string:)` used for
        // reg-name hosts: confirm Foundation round-trips the canonical IPv6 literal
        // as a colon-bearing host. No IDNA applies here — the address is already
        // ASCII — so the strict initializer would behave identically; the lenient
        // form is kept for parity with the reg-name path above.
        guard
            let url = URL(string: "https://[\(normalizedAddress)]"),
            url.host(percentEncoded: false)?.contains(":") == true
        else {
            throw .invalidIPv6Address(rawAddress)
        }

        return "[\(normalizedAddress)]"
    }

    static func validatedIPLiteral(_ rawLiteral: String) throws(URLBuildError) -> String {
        guard let literal = unbracketedLiteral(rawLiteral) else {
            throw .invalidIPLiteral(rawLiteral)
        }
        if let normalizedIPv6Address = normalizedIPv6Address(literal) {
            return "[\(normalizedIPv6Address)]"
        }

        guard isValidIPvFuture(literal) else {
            throw .invalidIPLiteral(rawLiteral)
        }

        return "[\(literal.lowercased())]"
    }

    static func validatedPathSegment(_ segment: String) throws(URLBuildError) -> String {
        guard
            segment != ".",
            segment != "..",
            segment.contains("/") == false,
            segment.contains("\\") == false,
            segment.containsForbiddenIRIScalar == false
        else {
            throw .invalidPathSegment(segment)
        }

        // RFC 3986 §3.3 + §5.2.4 — dot segments MUST be removed during reference
        // resolution. Reject percent-encoded dot segments (e.g. "%2e", "%2E",
        // "%2e%2e") so they cannot smuggle traversal past the dot-segment guard.
        if let decoded = segment.removingPercentEncoding, decoded != segment {
            if decoded == "." || decoded == ".."
                || decoded.contains("/") || decoded.contains("\\")
                || decoded.containsForbiddenIRIScalar
            {
                throw .invalidPathSegment(segment)
            }
        }

        return segment
    }

    /// Enforces that a composed top-level domain is a known public suffix.
    ///
    /// When `enforcement` is `.strict`, the lowercased `tld` must appear in the
    /// embedded ICANN public-suffix list; permissive mode is a no-op.
    static func enforce(
        _ enforcement: URLBuildConfiguration.TLDEnforcement,
        on tld: TopLevelDomain
    ) throws(URLBuildError) {
        guard enforcement == .strict else { return }
        let normalized = tld.rawValue.lowercased()
        guard PublicSuffix.contains(normalized) else {
            throw .unknownTopLevelDomain(tld.rawValue)
        }
    }

    /// Enforces that a host ends with a known public suffix.
    ///
    /// When `enforcement` is `.strict`, `host` must have a longest-match in the
    /// embedded ICANN public-suffix list. IPv4 literals are exempt; IPv6
    /// literals never reach this path; permissive mode is a no-op.
    static func enforcePublicSuffix(
        _ enforcement: URLBuildConfiguration.TLDEnforcement,
        on host: String
    ) throws(URLBuildError) {
        guard enforcement == .strict else { return }
        if looksLikeIPv4Literal(host) { return }
        if PublicSuffix.longestMatch(for: host) == nil {
            let lastLabel = host.split(separator: ".").last.map(String.init) ?? host
            throw .unknownPublicSuffix(host: host, label: lastLabel)
        }
    }

    /// Renders `string` as `application/x-www-form-urlencoded` text.
    ///
    /// Per the WHATWG URL Standard: SPACE becomes `+`, a literal `+` becomes
    /// `%2B`, and all other reserved bytes are percent-encoded as UTF-8.
    /// Pass-through bytes follow the HTML form-encoding set (alphanumerics plus
    /// `*`, `-`, `.`, `_`).
    static func formURLEncoded(_ string: String) -> String {
        let percentEncoded =
            string.addingPercentEncoding(
                withAllowedCharacters: formURLEncodedAllowed
            ) ?? ""
        return percentEncoded.replacingOccurrences(of: "%20", with: "+")
    }

    static func percentEncodedUserInfoSubcomponent(
        _ string: String,
        allowEmpty: Bool
    ) throws(URLBuildError) -> String {
        guard allowEmpty || string.isEmpty == false else {
            throw .invalidUserInfo
        }

        guard string.containsForbiddenIRIScalar == false else {
            throw .invalidUserInfo
        }

        guard
            let encoded = string.addingPercentEncoding(withAllowedCharacters: userInfoAllowed),
            allowEmpty || encoded.isEmpty == false
        else {
            throw .invalidUserInfo
        }

        return encoded
    }

    private static let formURLEncodedAllowed: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        set.insert(charactersIn: "0123456789")
        set.insert(charactersIn: "*-._")
        return set
    }()

    private static let userInfoAllowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
    )

    /// Whether `host` is an IPv4 literal, for PSL-enforcement exemption.
    ///
    /// Uses the platform `inet_pton(AF_INET, …)` so the exemption matches exactly
    /// what the OS (and Foundation's host parser) treats as an IPv4 address,
    /// closing the seam where a textual 4-dotted-decimal heuristic and Foundation
    /// could disagree about whether a host is an IP. Non-POSIX platforms (no
    /// `inet_pton`) fall back to the textual heuristic.
    private static func looksLikeIPv4Literal(_ host: String) -> Bool {
        #if canImport(Darwin) || canImport(Glibc)
            var address = in_addr()
            return host.withCString { pointer in
                inet_pton(AF_INET, pointer, &address) == 1
            }
        #else
            let parts = host.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 4 else { return false }
            return parts.allSatisfy { part in
                part.isEmpty == false && part.allSatisfy(\.isASCIIDigit)
            }
        #endif
    }

    static func validatedFragment(_ fragment: String) throws(URLBuildError) -> String {
        // RFC 3986 §3.5 + RFC 3987 §4.1 + RFC 9110 §11.7.6 — fragment
        // MUST NOT contain controls, line separators, or bidi controls.
        guard fragment.containsForbiddenIRIScalar == false else {
            throw .invalidFragment(fragment)
        }

        return fragment
    }

    // RFC 5892 §2.4 — DISALLOWED codepoints in U-labels.
    // CONTEXTJ/CONTEXTO are intentionally conservative here: Foundation
    // applies contextual IDNA rules after this pre-filter, so bare format
    // codepoints are rejected before lookup rather than accepted broadly.
    // Backed by Unicode general categories (UnicodeData.txt) and the
    // Noncharacter_Code_Point property (DerivedCoreProperties.txt).
    // ASCII (< 0x80) is handled by validatedHostLabel which only accepts
    // letters, digits, and HYPHEN-MINUS.
    private static func rejectDISALLOWEDCodepoints(in rawHost: String)
        throws(URLBuildError)
    {
        for scalar in rawHost.unicodeScalars {
            if scalar.value < 0x80 { continue }

            // Non-character codepoints: U+FDD0..U+FDEF and any codepoint whose
            // low 16 bits are 0xFFFE or 0xFFFF (UnicodeData / Unicode Standard
            // §23.7). DISALLOWED per RFC 5892 §2.4.
            if (0xFDD0...0xFDEF).contains(scalar.value) {
                throw .invalidHost(rawHost)
            }
            let low16 = scalar.value & 0xFFFF
            if low16 == 0xFFFE || low16 == 0xFFFF {
                throw .invalidHost(rawHost)
            }

            switch scalar.properties.generalCategory {
                // Symbols (Sm/Sc/Sk/So) — emoji, math, currency, modifier symbols.
                case .otherSymbol, .mathSymbol, .modifierSymbol, .currencySymbol,
                    // Punctuation (Pc/Pd/Ps/Pe/Pi/Pf/Po).
                    .openPunctuation, .closePunctuation, .initialPunctuation,
                    .finalPunctuation, .otherPunctuation, .dashPunctuation,
                    .connectorPunctuation,
                    // Separators (Zs/Zl/Zp).
                    .spaceSeparator, .lineSeparator, .paragraphSeparator,
                    // Other (Cc/Cf/Cs/Co/Cn).
                    .control, .format, .surrogate, .privateUse, .unassigned:
                    throw .invalidHost(rawHost)
                default:
                    continue
            }
        }
    }

    private static func validatedHostLabel(_ label: String) throws(URLBuildError) {
        guard label.isEmpty == false, label.utf8.count <= 63 else {
            throw .invalidHostLabel(label)
        }

        guard label.first?.isASCIIAlphanumeric == true, label.last?.isASCIIAlphanumeric == true
        else {
            throw .invalidHostLabel(label)
        }

        guard
            label.allSatisfy({ character in
                character.isASCIIAlpha || character.isASCIIDigit || character == "-"
            })
        else {
            throw .invalidHostLabel(label)
        }
    }

    private static func isInvalidIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }) else {
            return false
        }

        return parts.contains { part in
            guard let value = Int(part), (0...255).contains(value) else {
                return true
            }

            return part.count > 1 && part.first == "0"
        }
    }

    private static func unbracketedLiteral(_ rawLiteral: String) -> String? {
        let trimmedLiteral = rawLiteral.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLiteral == rawLiteral, trimmedLiteral.isEmpty == false else {
            return nil
        }

        let hasOpeningBracket = trimmedLiteral.hasPrefix("[")
        let hasClosingBracket = trimmedLiteral.hasSuffix("]")

        if hasOpeningBracket || hasClosingBracket {
            guard hasOpeningBracket, hasClosingBracket else {
                return nil
            }

            let innerLiteral = String(trimmedLiteral.dropFirst().dropLast())
            guard
                innerLiteral.isEmpty == false,
                innerLiteral.contains("[") == false,
                innerLiteral.contains("]") == false
            else {
                return nil
            }

            return innerLiteral
        }

        guard trimmedLiteral.contains("[") == false, trimmedLiteral.contains("]") == false else {
            return nil
        }

        return trimmedLiteral
    }

    private static func normalizedIPv6Address(_ address: String) -> String? {
        guard address.isEmpty == false, address.contains(":"), address.contains("%") == false else {
            return nil
        }

        #if canImport(Darwin) || canImport(Glibc)
            var storage = in6_addr()
            let parseResult = address.withCString { pointer in
                inet_pton(AF_INET6, pointer, &storage) == 1
            }
            guard parseResult else {
                return nil
            }

            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard
                inet_ntop(AF_INET6, &storage, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil
            else {
                return nil
            }

            let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self).lowercased()
        #else
            // No POSIX `inet_pton`/`inet_ntop` is available here (e.g. Windows). Fail closed by
            // returning `nil` so the caller rejects the IPv6 literal, rather than emitting a
            // `#warning` — which `treatAllWarnings(as: .error)` would turn into a hard build break.
            return nil
        #endif
    }

    private static func isValidIPvFuture(_ literal: String) -> Bool {
        guard literal.count >= 4, literal.first == "v" || literal.first == "V" else {
            return false
        }

        let afterVersionPrefix = literal.dropFirst()
        guard let dotIndex = afterVersionPrefix.firstIndex(of: ".") else {
            return false
        }

        let version = afterVersionPrefix[..<dotIndex]
        let address = afterVersionPrefix[afterVersionPrefix.index(after: dotIndex)...]
        guard version.isEmpty == false, address.isEmpty == false else {
            return false
        }

        guard version.allSatisfy(\.isASCIIHexDigit) else {
            return false
        }

        return address.allSatisfy { character in
            character.isASCIIAlpha || character.isASCIIDigit || character == "-" || character == "."
                || character == "_" || character == "~" || character.isSubDelimiter
                || character == ":"
        }
    }
}

extension Character {
    fileprivate var isHostDelimiter: Bool {
        switch self {
            case "/", "\\", "?", "#", "@":
                true
            default:
                false
        }
    }
}
