import Foundation

/// Collects host labels and host-specific declarations.
@resultBuilder
public enum URLHostBuilder {
    public static func buildExpression(_ expression: Host) -> [Host] {
        [expression]
    }

    /// Adds one unclassified host label.
    ///
    /// If this builder also contains a
    /// TLD and no explicit domain, the last string label is inferred as
    /// the registered domain.
    public static func buildExpression(_ expression: String) -> [Host] {
        [.label(expression)]
    }

    public static func buildExpression(_ expression: TopLevelDomain) -> [Host] {
        [.topLevelDomain(expression)]
    }

    public static func buildExpression(_ expression: Host?) -> [Host] {
        expression.map { [$0] } ?? []
    }

    public static func buildBlock(_ components: [Host]...) -> [Host] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [Host]?) -> [Host] {
        component ?? []
    }

    public static func buildEither(first component: [Host]) -> [Host] {
        component
    }

    public static func buildEither(second component: [Host]) -> [Host] {
        component
    }

    public static func buildArray(_ components: [[Host]]) -> [Host] {
        components.flatMap(\.self)
    }
}

/// Collects a single root URL declaration.
@resultBuilder
public enum URLRootBuilder {
    public static func buildExpression(_ expression: URLDeclaration) -> [URLDeclaration] {
        [expression]
    }

    public static func buildExpression(_ expression: HTTPS) -> [URLDeclaration] {
        [expression.declaration]
    }

    public static func buildExpression(_ expression: HTTP) -> [URLDeclaration] {
        [expression.declaration]
    }

    public static func buildBlock(_ components: [URLDeclaration]...) -> [URLDeclaration] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [URLDeclaration]?) -> [URLDeclaration] {
        component ?? []
    }

    public static func buildEither(first component: [URLDeclaration]) -> [URLDeclaration] {
        component
    }

    public static func buildEither(second component: [URLDeclaration]) -> [URLDeclaration] {
        component
    }

    public static func buildArray(_ components: [[URLDeclaration]]) -> [URLDeclaration] {
        components.flatMap(\.self)
    }
}

/// Collects URL components inside a scheme declaration.
@resultBuilder
public enum URLComponentBuilder {
    public static func buildExpression(_ expression: URLComponent) -> [URLComponent] {
        [expression]
    }

    public static func buildExpression(_ expression: URLComponent?) -> [URLComponent] {
        expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ expression: Host) -> [URLComponent] {
        [URLComponent(storages: expression.storages)]
    }

    public static func buildExpression(_ expression: UserInfo) -> [URLComponent] {
        [URLComponent(storage: .userInfo(expression))]
    }

    public static func buildExpression(_ expression: Subdomain) -> [URLComponent] {
        [URLComponent(storage: .subdomain(expression.label))]
    }

    public static func buildExpression(_ expression: Domain) -> [URLComponent] {
        [URLComponent(storage: .domain(expression.label))]
    }

    public static func buildExpression(_ expression: TopLevelDomain) -> [URLComponent] {
        [URLComponent(storage: .tld(expression))]
    }

    public static func buildExpression(_ expression: Path) -> [URLComponent] {
        [URLComponent(storage: .path(expression.segments))]
    }

    public static func buildExpression(_ expression: Query) -> [URLComponent] {
        [URLComponent(storage: .queries([expression]))]
    }

    public static func buildExpression(_ expression: Query?) -> [URLComponent] {
        expression.map { [URLComponent(storage: .queries([$0]))] } ?? []
    }

    public static func buildExpression(_ expression: Fragment) -> [URLComponent] {
        [URLComponent(storage: .fragment(expression.value))]
    }

    public static func buildExpression(_ expression: Port) -> [URLComponent] {
        [URLComponent(storage: .port(expression.value))]
    }

    public static func buildExpression(_ expression: IPv6) -> [URLComponent] {
        [URLComponent(storage: .ipv6(expression.address))]
    }

    public static func buildExpression(_ expression: IPLiteral) -> [URLComponent] {
        [URLComponent(storage: .ipLiteral(expression.literal))]
    }

    public static func buildExpression(_ expression: IPvFuture) -> [URLComponent] {
        [URLComponent(storage: .ipLiteral(expression.literal))]
    }

    /// Expands a `URLQueryRepresentable` value into a single component
    /// holding the value's full query item list.
    public static func buildExpression<R: URLQueryRepresentable>(_ expression: R) -> [URLComponent] {
        let queries = expression.urlQuery
        return queries.isEmpty ? [] : [URLComponent(storage: .queries(queries))]
    }

    public static func buildBlock(_ components: [URLComponent]...) -> [URLComponent] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [URLComponent]?) -> [URLComponent] {
        component ?? []
    }

    public static func buildEither(first component: [URLComponent]) -> [URLComponent] {
        component
    }

    public static func buildEither(second component: [URLComponent]) -> [URLComponent] {
        component
    }

    public static func buildArray(_ components: [[URLComponent]]) -> [URLComponent] {
        components.flatMap(\.self)
    }
}

/// Collects path components.
@resultBuilder
public enum URLPathBuilder {
    public static func buildExpression(_ expression: String) -> [PathSegment] {
        [.segment(expression)]
    }

    public static func buildExpression(_ expression: PathSegment) -> [PathSegment] {
        [expression]
    }

    public static func buildExpression(_ expression: PathSegment?) -> [PathSegment] {
        expression.map { [$0] } ?? []
    }

    public static func buildBlock(_ components: [PathSegment]...) -> [PathSegment] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [PathSegment]?) -> [PathSegment] {
        component ?? []
    }

    public static func buildEither(first component: [PathSegment]) -> [PathSegment] {
        component
    }

    public static func buildEither(second component: [PathSegment]) -> [PathSegment] {
        component
    }

    public static func buildArray(_ components: [[PathSegment]]) -> [PathSegment] {
        components.flatMap(\.self)
    }
}

/// Collects query items.
@resultBuilder
public enum URLQueryBuilder {
    public static func buildExpression(_ expression: Query) -> [Query] {
        [expression]
    }

    public static func buildExpression(_ expression: Query?) -> [Query] {
        expression.map { [$0] } ?? []
    }

    /// Expands a `URLQueryRepresentable` value into its query item list.
    public static func buildExpression<R: URLQueryRepresentable>(_ expression: R) -> [Query] {
        expression.urlQuery
    }

    public static func buildBlock(_ components: [Query]...) -> [Query] {
        components.flatMap(\.self)
    }

    public static func buildOptional(_ component: [Query]?) -> [Query] {
        component ?? []
    }

    public static func buildEither(first component: [Query]) -> [Query] {
        component
    }

    public static func buildEither(second component: [Query]) -> [Query] {
        component
    }

    public static func buildArray(_ components: [[Query]]) -> [Query] {
        components.flatMap(\.self)
    }
}
