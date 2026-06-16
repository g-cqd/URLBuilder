public import Foundation

/// A URL declaration attached to a scheme.
///
/// Constructed by `HTTPS`, `HTTP`, or `URLDeclaration(scheme:_:)` for
/// custom schemes. Use `URLBuilder { … }` or `withThrowingURL { … }` to
/// turn declarations into `URL` values.
public struct URLDeclaration: Sendable {
    public let scheme: Scheme
    public let components: [URLComponent]

    internal init(scheme: Scheme, components: [URLComponent]) {
        self.scheme = scheme
        self.components = components
    }

    /// Creates a URL declaration with a custom scheme.
    public init(
        scheme: Scheme,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        self.scheme = scheme
        self.components = content()
    }

    /// Creates a URL declaration with a custom scheme and a complete host.
    public init(
        scheme: Scheme,
        host: String,
        @URLComponentBuilder _ content: () -> [URLComponent] = { [] }
    ) {
        self.scheme = scheme
        self.components = [URLComponent(storage: .host(host))] + content()
    }

    public func build() throws(URLBuildError) -> URL {
        try build(configuration: .default)
    }

    public func build(configuration: URLBuildConfiguration) throws(URLBuildError) -> URL {
        let normalizedScheme = try URLValidator.normalizedScheme(scheme.rawValue)
        let state = try URLDeclarationState(
            components: components,
            scheme: normalizedScheme,
            configuration: configuration
        )

        var components = URLComponents()
        components.scheme = normalizedScheme

        let resolvedHost = try state.resolvedHost()
        if let resolvedHost {
            components.encodedHost = resolvedHost
        }

        if let userInfo = try state.resolvedUserInfo(hasHost: resolvedHost != nil) {
            components.percentEncodedUser = userInfo.username
            components.percentEncodedPassword = userInfo.password
        }

        if let port = state.normalizedPort {
            components.port = port
        }

        components.path = try state.resolvedPath(hasHost: resolvedHost != nil)

        let queryItems = try state.queryItems()
        if queryItems.isEmpty == false {
            switch configuration.queryEncoding {
                case .rfc3986:
                    components.queryItems = queryItems
                case .formURLEncoded:
                    // Deliberately bypass `URLComponents.queryItems` and assign the
                    // already-encoded string to `percentEncodedQuery`: the `queryItems`
                    // setter applies RFC 3986 query encoding, which would re-encode our
                    // form bytes (turning `+` back into `%2B`, etc.). `formURLEncoded`
                    // has already produced the exact `application/x-www-form-urlencoded`
                    // octets, so they are stored verbatim.
                    components.percentEncodedQuery = queryItems.map { item in
                        let encodedName = URLValidator.formURLEncoded(item.name)
                        guard let value = item.value else { return encodedName }
                        return "\(encodedName)=\(URLValidator.formURLEncoded(value))"
                    }.joined(separator: "&")
            }
        }

        if let fragment = state.fragment {
            components.fragment = try URLValidator.validatedFragment(fragment)
        }

        guard let url = components.url else {
            throw .invalidURLComponents
        }

        return url
    }
}

internal struct URLDeclarationState {
    private enum HostDeclaration {
        case name(String)
        case ipv6(String)
        case ipLiteral(String)
    }

    let scheme: String
    let configuration: URLBuildConfiguration
    private var host: HostDeclaration?
    var hostLabels: [String] = []
    var subdomains: [String] = []
    var domain: String?
    var tld: TopLevelDomain?
    var userInfo: UserInfo?
    var port: Int?
    var pathSegments: [PathSegment] = []
    var queries: [Query] = []
    var fragment: String?

    var normalizedPort: Int? {
        guard let port else {
            return nil
        }

        if scheme == Scheme.http.rawValue, port == 80 {
            return nil
        }

        if scheme == Scheme.https.rawValue, port == 443 {
            return nil
        }

        return port
    }

    init(
        components: [URLComponent],
        scheme: String,
        configuration: URLBuildConfiguration
    ) throws(URLBuildError) {
        self.scheme = scheme
        self.configuration = configuration

        for component in components {
            for storage in component.storages {
                switch storage {
                    case .subdomain(let label):
                        subdomains.append(label)
                    case .hostLabels(let labels):
                        hostLabels.append(contentsOf: labels)
                    case .domain(let label):
                        guard domain == nil else {
                            throw .duplicateDomain
                        }
                        domain = label
                    case .tld(let value):
                        guard tld == nil else {
                            throw .duplicateTopLevelDomain
                        }
                        tld = value
                    case .host(let name):
                        guard host == nil else {
                            throw .conflictingHostDeclarations
                        }
                        host = .name(name)
                    case .ipv6(let address):
                        guard host == nil else {
                            throw .conflictingHostDeclarations
                        }
                        host = .ipv6(address)
                    case .ipLiteral(let literal):
                        guard host == nil else {
                            throw .conflictingHostDeclarations
                        }
                        host = .ipLiteral(literal)
                    case .userInfo(let value):
                        guard userInfo == nil else {
                            throw .duplicateUserInfo
                        }
                        userInfo = value
                    case .port(let value):
                        guard port == nil else {
                            throw .duplicatePort
                        }
                        // RFC 6335 §6: TCP/UDP port range is 1..65535. Port 0 is reserved
                        // and MUST NOT be used in URIs (RFC 9110 §4.2.1).
                        guard (1...65_535).contains(value) else {
                            throw .invalidPort(value)
                        }
                        port = value
                    case .path(let value):
                        pathSegments.append(contentsOf: value)
                    case .queries(let value):
                        queries.append(contentsOf: value)
                    case .fragment(let value):
                        guard fragment == nil else {
                            throw .duplicateFragment
                        }
                        fragment = value
                }
            }
        }
    }

    func resolvedHost() throws(URLBuildError) -> String? {
        let hasHostLabels = hostLabels.isEmpty == false
        let hasComposedHost =
            hasHostLabels || subdomains.isEmpty == false || domain != nil || tld != nil

        if host != nil, hasComposedHost {
            throw .conflictingHostDeclarations
        }

        let resolvedHost: String?
        if let host {
            resolvedHost = try resolve(host)
        } else if hasHostLabels, subdomains.isEmpty, domain == nil, tld == nil {
            let normalized = try URLValidator.validatedHostName(hostLabels.joined(separator: "."))
            try URLValidator.enforcePublicSuffix(configuration.tldEnforcement, on: normalized)
            resolvedHost = normalized
        } else if hasComposedHost {
            let resolvedDomain: String
            let resolvedSubdomains: [String]

            if let domain {
                resolvedDomain = domain
                resolvedSubdomains = subdomains + hostLabels
            } else if let inferredDomain = hostLabels.last {
                resolvedDomain = inferredDomain
                resolvedSubdomains = subdomains + Array(hostLabels.dropLast())
            } else {
                throw .missingDomain
            }

            guard let tld else {
                throw .missingTopLevelDomain
            }

            try URLValidator.enforce(configuration.tldEnforcement, on: tld)

            resolvedHost = try composedHost(
                subdomains: resolvedSubdomains,
                domain: resolvedDomain,
                tld: tld
            )
        } else {
            resolvedHost = nil
        }

        if resolvedHost == nil {
            if port != nil {
                throw .portRequiresHost
            }

            if scheme == Scheme.http.rawValue || scheme == Scheme.https.rawValue {
                throw .missingHost(scheme: scheme)
            }
        }

        return resolvedHost
    }

    func resolvedUserInfo(hasHost: Bool) throws(URLBuildError) -> (
        username: String, password: String?
    )? {
        guard let userInfo else { return nil }

        switch configuration.userInfoPolicy {
            case .disabled:
                throw .userInfoDisabled
            case .usernameOnly:
                if userInfo.password != nil {
                    throw .passwordUserInfoDisabled
                }
            case .usernameAndPassword:
                break
        }

        guard hasHost else {
            throw .userInfoRequiresHost
        }

        let username = try URLValidator.percentEncodedUserInfoSubcomponent(
            userInfo.username,
            allowEmpty: false
        )
        let password: String?
        if let rawPassword = userInfo.password {
            password = try URLValidator.percentEncodedUserInfoSubcomponent(
                rawPassword,
                allowEmpty: true
            )
        } else {
            password = nil
        }

        return (username, password)
    }

    func resolvedPath(hasHost: Bool) throws(URLBuildError) -> String {
        guard pathSegments.isEmpty == false else {
            return ""
        }

        var segments: [String] = []
        for component in pathSegments {
            for value in component.values {
                segments.append(try URLValidator.validatedPathSegment(value))
            }
        }

        if hasHost == false {
            if segments.first?.contains(":") == true {
                throw .invalidURLComponents
            }
            return segments.joined(separator: "/")
        }

        return "/" + segments.joined(separator: "/")
    }

    func queryItems() throws(URLBuildError) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        for query in queries {
            for item in query.items {
                guard item.name.isEmpty == false else {
                    throw .emptyQueryName
                }

                // RFC 3986 §3.4 + RFC 9110 §11.7.6 (CRLF/header injection)
                // — query name MUST NOT contain CR/LF or other C0 controls.
                guard item.name.containsForbiddenIRIScalar == false else {
                    throw .invalidQueryName(item.name)
                }

                let value = try item.value.rawValue(name: item.name)
                if let value, value.containsForbiddenIRIScalar {
                    throw .invalidQueryValue(name: item.name, value: value)
                }

                items.append(URLQueryItem(name: item.name, value: value))
            }
        }

        return Self.applyDeduplication(configuration.queryDeduplication, to: items)
    }

    /// Applies the configured dedup policy.
    ///
    /// Both `.lastWins` and `.firstWins`
    /// keep the surviving entry at the *first occurrence's position* in the
    /// rendered URL — matching `URLSearchParams.set` placement semantics
    /// (WHATWG URL §6.2). Only the surviving entry's value differs.
    private static func applyDeduplication(
        _ policy: URLBuildConfiguration.QueryDeduplication,
        to items: [URLQueryItem]
    ) -> [URLQueryItem] {
        switch policy {
            case .none:
                return items
            case .firstWins:
                var seen: Set<String> = []
                return items.filter { item in seen.insert(item.name).inserted }
            case .lastWins:
                var latestByName: [String: URLQueryItem] = [:]
                for item in items {
                    latestByName[item.name] = item
                }
                var seen: Set<String> = []
                var deduped: [URLQueryItem] = []
                deduped.reserveCapacity(items.count)
                for item in items {
                    guard seen.insert(item.name).inserted else { continue }
                    if let latest = latestByName[item.name] {
                        deduped.append(latest)
                    }
                }
                return deduped
        }
    }

    private func resolve(_ host: HostDeclaration) throws(URLBuildError) -> String {
        switch host {
            case .name(let name):
                let normalized = try URLValidator.validatedHostName(name)
                try URLValidator.enforcePublicSuffix(configuration.tldEnforcement, on: normalized)
                return normalized
            case .ipv6(let address):
                return try URLValidator.validatedIPv6Address(address)
            case .ipLiteral(let literal):
                return try URLValidator.validatedIPLiteral(literal)
        }
    }

    private func composedHost(
        subdomains: [String],
        domain: String,
        tld: TopLevelDomain
    ) throws(URLBuildError) -> String {
        let tldLabels = tld.rawValue.split(separator: ".", omittingEmptySubsequences: false).map(
            String.init)
        guard let finalTLDLabel = tldLabels.last, finalTLDLabel.isEmpty == false else {
            throw .invalidTopLevelDomain(tld.rawValue)
        }

        guard finalTLDLabel.count >= 2, finalTLDLabel.contains(where: \.isLetter) else {
            throw .invalidTopLevelDomain(tld.rawValue)
        }

        let labels = subdomains + [domain] + tldLabels
        let host = labels.joined(separator: ".")
        let normalizedHost = try URLValidator.validatedHostName(host)

        return normalizedHost
    }
}
