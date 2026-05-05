import Foundation

/// A host declaration.
///
/// `Host` plays two roles: it is the value type produced by `Host { … }`
/// when set as a URL component, and it is the element type collected by
/// `@URLHostBuilder` blocks. Inside a host builder, callers compose
/// hosts via static factories (`Host.subdomain(_:)`, `Host.domain(_:)`,
/// `Host.topLevelDomain(_:)`, …) or their dot-shorthand forms.
public struct Host: Sendable {
    internal let storages: [URLComponent.Storage]

    /// Sets a complete DNS host name or IPv4 address.
    public init(_ name: String) {
        self.storages = [.host(name)]
    }

    /// Composes a host from typed declarations.
    public init(@URLHostBuilder _ content: () -> [Host]) {
        self.storages = content().flatMap(\.storages)
    }

    internal init(storages: [URLComponent.Storage]) {
        self.storages = storages
    }

    /// Adds one subdomain label. Multiple declarations preserve order.
    public static func subdomain(_ label: String) -> Host {
        Host(storages: [.subdomain(label)])
    }

    /// Adds one subdomain label. Multiple declarations preserve order.
    public func subdomain(_ label: String) -> Host {
        appending(.subdomain(label))
    }

    /// Adds one unclassified host label.
    ///
    /// When a host builder also declares a TLD but no explicit domain,
    /// the last unclassified label becomes the registered domain and
    /// earlier labels become subdomains.
    public static func label(_ label: String) -> Host {
        Host(storages: [.hostLabels([label])])
    }

    /// Adds one unclassified host label.
    public func label(_ label: String) -> Host {
        appending(.hostLabels([label]))
    }

    /// Adds unclassified host labels.
    public static func labels(_ labels: String...) -> Host {
        Host(storages: [.hostLabels(labels)])
    }

    /// Adds unclassified host labels.
    public func labels(_ labels: String...) -> Host {
        appending(.hostLabels(labels))
    }

    /// Sets the registered domain label.
    public static func domain(_ label: String) -> Host {
        Host(storages: [.domain(label)])
    }

    /// Sets the registered domain label.
    public func domain(_ label: String) -> Host {
        appending(.domain(label))
    }

    /// Sets the top-level domain or public suffix.
    public static func topLevelDomain(_ tld: TopLevelDomain) -> Host {
        Host(storages: [.tld(tld)])
    }

    /// Sets the top-level domain or public suffix.
    public func topLevelDomain(_ tld: TopLevelDomain) -> Host {
        appending(.tld(tld))
    }

    /// Sets the top-level domain or public suffix. Shorthand for `topLevelDomain`.
    public static func tld(_ tld: TopLevelDomain) -> Host {
        .topLevelDomain(tld)
    }

    /// Sets the top-level domain or public suffix. Shorthand for `topLevelDomain`.
    public func tld(_ tld: TopLevelDomain) -> Host {
        topLevelDomain(tld)
    }

    /// Sets a complete DNS host name or IPv4 address.
    public static func name(_ host: String) -> Host {
        Host(storages: [.host(host)])
    }

    /// Sets an IPv6 host literal. Brackets are optional in the argument.
    ///
    /// IPv6 parsing uses the platform C library (`inet_pton`/`inet_ntop`)
    /// and is available on Darwin and Glibc platforms.
    public static func ipv6(_ address: String) -> Host {
        Host(storages: [.ipv6(address)])
    }

    /// Sets an RFC 3986 IP literal, including IPv6 or IPvFuture.
    public static func ipLiteral(_ literal: String) -> Host {
        Host(storages: [.ipLiteral(literal)])
    }

    /// Sets an RFC 3986 IPvFuture host literal.
    public static func ipvFuture(_ literal: String) -> Host {
        .ipLiteral(literal)
    }

    private func appending(_ storage: URLComponent.Storage) -> Host {
        Host(storages: storages + [storage])
    }
}
