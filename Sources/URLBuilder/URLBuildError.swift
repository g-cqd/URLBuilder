import Foundation

/// Validation failures for URL declarations.
public enum URLBuildError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingRootURL
    case multipleRootURLs
    case invalidScheme(String)
    case missingHost(scheme: String)
    case conflictingHostDeclarations
    case missingDomain
    case missingTopLevelDomain
    case duplicateDomain
    case duplicateTopLevelDomain
    case duplicateUserInfo
    case duplicatePort
    case duplicateFragment
    case userInfoDisabled
    case passwordUserInfoDisabled
    case userInfoRequiresHost
    case portRequiresHost
    case invalidUserInfo
    case invalidHost(String)
    case invalidHostLabel(String)
    case invalidTopLevelDomain(String)
    case invalidIPv6Address(String)
    case invalidIPLiteral(String)
    case invalidPort(Int)
    case invalidPathSegment(String)
    case invalidQueryName(String)
    case invalidQueryValue(name: String, value: String)
    case invalidQueryValueEncoding(name: String)
    case invalidFragment(String)
    case emptyQueryName
    case invalidURLComponents
    case unknownTopLevelDomain(String)
    case unknownPublicSuffix(host: String, label: String)

    public var description: String {
        switch self {
            case .missingRootURL:
                "URLBuilder requires exactly one root URL declaration."
            case .multipleRootURLs:
                "URLBuilder accepts exactly one root URL declaration."
            case .invalidScheme(let scheme):
                "Invalid URL scheme: \(scheme)."
            case .missingHost(let scheme):
                "The \(scheme) scheme requires a host."
            case .conflictingHostDeclarations:
                "Use either .host/.ipv6 or composed host declarations, not both."
            case .missingDomain:
                "A composed host requires .domain."
            case .missingTopLevelDomain:
                "A composed host requires .tld."
            case .duplicateDomain:
                "Only one .domain declaration is allowed."
            case .duplicateTopLevelDomain:
                "Only one .tld declaration is allowed."
            case .duplicateUserInfo:
                "Only one userinfo declaration is allowed."
            case .duplicatePort:
                "Only one .port declaration is allowed."
            case .duplicateFragment:
                "Only one .fragment declaration is allowed."
            case .userInfoDisabled:
                "Userinfo is disabled by this URLBuildConfiguration."
            case .passwordUserInfoDisabled:
                "Password userinfo is disabled by this URLBuildConfiguration."
            case .userInfoRequiresHost:
                "Userinfo requires an authority host."
            case .portRequiresHost:
                "A port requires a host."
            case .invalidUserInfo:
                "Invalid userinfo."
            case .invalidHost(let host):
                "Invalid host: \(host)."
            case .invalidHostLabel(let label):
                "Invalid host label: \(label)."
            case .invalidTopLevelDomain(let tld):
                "Invalid top-level domain: \(tld)."
            case .invalidIPv6Address(let address):
                "Invalid IPv6 address: \(address)."
            case .invalidIPLiteral(let literal):
                "Invalid IP literal: \(literal)."
            case .invalidPort(let port):
                "Invalid port: \(port)."
            case .invalidPathSegment(let segment):
                "Invalid path segment: \(segment)."
            case .invalidQueryName(let name):
                "Invalid query name: \(name)."
            case .invalidQueryValue(let name, let value):
                "Invalid query value for \(name): \(value)."
            case .invalidQueryValueEncoding(let name):
                "Could not encode query value for \(name)."
            case .invalidFragment(let fragment):
                "Invalid fragment: \(fragment)."
            case .emptyQueryName:
                "Query item names cannot be empty."
            case .invalidURLComponents:
                "Foundation could not produce a URL from the declaration."
            case .unknownTopLevelDomain(let value):
                "Unknown top-level domain or public suffix: \(value)."
            case .unknownPublicSuffix(let host, let label):
                "Host \(host) does not end with a known public suffix (last label: \(label))."
        }
    }
}
