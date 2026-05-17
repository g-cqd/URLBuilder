import Foundation

/// An HTTPS URL declaration.
public struct HTTPS: Sendable {
    internal let declaration: URLDeclaration

    /// Declares an HTTPS URL with no implicit host.
    ///
    /// Components inside the
    /// builder must declare a host.
    public init(@URLComponentBuilder _ content: () -> [URLComponent]) {
        declaration = URLDeclaration(scheme: .https, components: content())
    }

    /// Declares an HTTPS URL with a complete host string.
    public init(
        _ host: String,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        declaration = URLDeclaration(
            scheme: .https,
            components: [URLComponent(storage: .host(host))] + content()
        )
    }

    /// Declares an HTTPS URL with a registered domain and public-suffix label.
    public init(
        _ domain: String,
        _ tld: TopLevelDomain,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        declaration = URLDeclaration(
            scheme: .https,
            components: [
                URLComponent(storage: .domain(domain)),
                URLComponent(storage: .tld(tld)),
            ] + content()
        )
    }
}

/// An HTTP URL declaration.
public struct HTTP: Sendable {
    internal let declaration: URLDeclaration

    /// Declares an HTTP URL with no implicit host.
    ///
    /// Components inside the
    /// builder must declare a host.
    public init(@URLComponentBuilder _ content: () -> [URLComponent]) {
        declaration = URLDeclaration(scheme: .http, components: content())
    }

    /// Declares an HTTP URL with a complete host string.
    public init(
        _ host: String,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        declaration = URLDeclaration(
            scheme: .http,
            components: [URLComponent(storage: .host(host))] + content()
        )
    }

    /// Declares an HTTP URL with a registered domain and public-suffix label.
    public init(
        _ domain: String,
        _ tld: TopLevelDomain,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        declaration = URLDeclaration(
            scheme: .http,
            components: [
                URLComponent(storage: .domain(domain)),
                URLComponent(storage: .tld(tld)),
            ] + content()
        )
    }
}
