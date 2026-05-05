import Foundation

/// A declaration inside a scheme block.
///
/// User code does not construct `URLComponent` directly — values are
/// produced by the capitalized DSL types (`Path`, `Query`, `Subdomain`,
/// `Domain`, `Host`, `Fragment`, `Port`, `UserInfo`, `IPv6`, `IPLiteral`,
/// `IPvFuture`) which the result builders transform into components.
public struct URLComponent: Sendable {
    internal enum Storage: Sendable {
        case subdomain(String)
        case domain(String)
        case tld(TopLevelDomain)
        case host(String)
        case hostLabels([String])
        case ipv6(String)
        case ipLiteral(String)
        case userInfo(UserInfo)
        case port(Int)
        case path([PathSegment])
        case queries([Query])
        case fragment(String)
    }

    internal let storages: [Storage]

    internal init(storage: Storage) {
        storages = [storage]
    }

    internal init(storages: [Storage]) {
        self.storages = storages
    }
}
