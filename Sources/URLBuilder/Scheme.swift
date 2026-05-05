import Foundation

/// A URL scheme.
public struct Scheme: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public static let http = Scheme("http")
    public static let https = Scheme("https")

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

/// A top-level domain or public suffix convenience value.
///
/// Single-label TLDs (`com`, `org`, `fr`, …) are generated from the IANA
/// Root Zone Database by the public-suffix generator plugin. Multi-label
/// public suffixes are reachable through the `@dynamicMemberLookup`
/// chain syntax (`TLD.co.uk`, `TLD.com.au`, `TLD.aichi.nagoya`) and
/// resolved through `PublicSuffix.contains(_:)` when callers opt into
/// strict configuration.
@dynamicMemberLookup
public struct TopLevelDomain: Hashable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public var description: String {
        rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue.trimmingTLDPrefix(".").lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Creates a top-level domain or multi-label public suffix.
    public static func custom(_ rawValue: String) -> TopLevelDomain {
        TopLevelDomain(rawValue)
    }

    /// Extends a top-level domain with another suffix label.
    ///
    /// `TLD.co.uk` resolves to `TopLevelDomain("co.uk")`. The chain is
    /// not validated at this site; pass `.strict` to
    /// `withThrowingURL(configuration:_:)` (or `URLBuilder(configuration:_:)`)
    /// to reject suffix chains that are absent from
    /// `PublicSuffix.contains(_:)`.
    public subscript(dynamicMember member: String) -> TopLevelDomain {
        TopLevelDomain(rawValue + "." + member)
    }
}

/// Short spelling for top-level-domain declarations in DSL contexts.
public typealias TLD = TopLevelDomain

extension String {
    fileprivate func trimmingTLDPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return String(dropFirst(prefix.count))
    }
}
