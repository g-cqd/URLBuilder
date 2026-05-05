import Foundation

/// Configuration knobs that callers may opt into when building URLs.
///
/// The default configuration is permissive. Strict modes are opt-in via
/// `URLBuildConfiguration.strict` or per-field overrides.
public struct URLBuildConfiguration: Sendable, Equatable {
    /// Public-suffix enforcement applied to composed and string-based hosts.
    public enum TLDEnforcement: Sendable, Equatable {
        /// No public-suffix check. Default.
        case off
        /// The trailing public suffix of the host MUST appear in the ICANN
        /// section of the Mozilla Public Suffix List
        /// (`PublicSuffix.contains(_:)`).
        ///
        /// For composed hosts (`Host { … TLD.com }`) the `TopLevelDomain`
        /// raw value is checked directly. For full host strings
        /// (`Host("example.com")`) the longest-match suffix is required to
        /// be present. IPv4 and IPv6 literals are exempt.
        case strict
    }

    /// Output shape used when rendering the query component.
    public enum QueryEncoding: Sendable, Equatable {
        /// RFC 3986 §2.1 — render SPACE as `%20`. Default.
        case rfc3986
        /// WHATWG `application/x-www-form-urlencoded` — render SPACE as
        /// `+` and percent-encode literal `+` as `%2B`. Use when the
        /// receiving system (HTML form, browser, form-shaped backend)
        /// expects form-encoded query strings. Validation rules are
        /// unchanged; this is a rendering preference only.
        case formURLEncoded
    }

    /// Userinfo emission policy for URI authority components.
    public enum UserInfoPolicy: Sendable, Equatable {
        /// Reject all explicit userinfo declarations. Default.
        case disabled
        /// Allow a username only. Password declarations still fail.
        case usernameOnly
        /// Allow username and password declarations.
        ///
        /// RFC 3986 §3.2.1 permits the generic syntax but deprecates
        /// password-style userinfo. RFC 9110 §4.2.4 deprecates userinfo in
        /// `http(s)` URIs; use this only for explicit compatibility cases.
        case usernameAndPassword
    }

    /// Render-time deduplication policy for repeated query keys.
    ///
    /// RFC 3986 §3.4 + WHATWG URL Living Standard §5.1 both define the
    /// query as an ordered list of name-value pairs and preserve
    /// duplicates verbatim — this matches `.none`, the default. The
    /// `.lastWins` and `.firstWins` policies collapse duplicates while
    /// keeping the *first occurrence's position* in the rendered URL,
    /// matching the placement semantics of `URLSearchParams.set` (WHATWG
    /// URL §6.2). The surviving entry's value is determined by the policy.
    public enum QueryDeduplication: Sendable, Equatable {
        /// Preserve every declaration. Default.
        case none
        /// Keep one entry per key with the *last* declaration's value, at
        /// the position where the first declaration appeared.
        case lastWins
        /// Keep one entry per key with the *first* declaration's value, at
        /// the position where the first declaration appeared.
        case firstWins
    }

    public var tldEnforcement: TLDEnforcement
    public var queryEncoding: QueryEncoding
    public var userInfoPolicy: UserInfoPolicy
    public var queryDeduplication: QueryDeduplication

    public init(
        tldEnforcement: TLDEnforcement = .off,
        queryEncoding: QueryEncoding = .rfc3986,
        userInfoPolicy: UserInfoPolicy = .disabled,
        queryDeduplication: QueryDeduplication = .none
    ) {
        self.tldEnforcement = tldEnforcement
        self.queryEncoding = queryEncoding
        self.userInfoPolicy = userInfoPolicy
        self.queryDeduplication = queryDeduplication
    }

    /// Permissive configuration — matches the locked default.
    public static let `default` = URLBuildConfiguration()

    /// Strict public-suffix configuration.
    ///
    /// This only enables `tldEnforcement: .strict`; query encoding and
    /// all other validation policies keep their defaults.
    public static let strict = URLBuildConfiguration(tldEnforcement: .strict)

    /// Returns a copy with the given query-deduplication policy.
    public func queryDeduplication(_ policy: QueryDeduplication) -> URLBuildConfiguration {
        var copy = self
        copy.queryDeduplication = policy
        return copy
    }
}
