import Foundation

/// Adds one subdomain label.
public struct Subdomain: Sendable {
    internal let label: String

    public init(_ label: String) {
        self.label = label
    }
}

/// Sets the registered domain label.
public struct Domain: Sendable {
    internal let label: String

    public init(_ label: String) {
        self.label = label
    }
}

/// Appends path segments.
public struct Path: Sendable {
    internal let segments: [PathSegment]

    /// Appends path segments from a comma-separated list.
    public init(_ segments: String...) {
        self.segments = segments.map { PathSegment($0) }
    }

    /// Appends path segments collected by a result builder.
    public init(@URLPathBuilder _ content: () -> [PathSegment]) {
        self.segments = content()
    }
}

/// Sets the fragment without a leading `#`.
public struct Fragment: Sendable {
    internal let value: String

    public init(_ value: String) {
        self.value = value
    }
}

/// Sets the port. Default HTTP and HTTPS ports are omitted when rendering.
public struct Port: Sendable {
    internal let value: Int

    public init(_ value: Int) {
        self.value = value
    }
}

/// Sets an IPv6 host literal. Brackets are optional in the argument.
///
/// IPv6 parsing uses the platform C library (`inet_pton`/`inet_ntop`)
/// and is available on Darwin and Glibc platforms.
public struct IPv6: Sendable {
    internal let address: String

    public init(_ address: String) {
        self.address = address
    }
}

/// Sets an RFC 3986 IP literal, including IPv6 or IPvFuture.
public struct IPLiteral: Sendable {
    internal let literal: String

    public init(_ literal: String) {
        self.literal = literal
    }
}

/// Sets an RFC 3986 IPvFuture host literal.
public struct IPvFuture: Sendable {
    internal let literal: String

    public init(_ literal: String) {
        self.literal = literal
    }
}
