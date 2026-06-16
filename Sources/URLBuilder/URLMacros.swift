public import Foundation

/// Builds a URL from a result-builder declaration. Traps on invalid input.
///
/// Equivalent to `URLBuilder { ... }`, but expressible as a literal in
/// property contexts where the function form would require a closure
/// expression on a separate line.
///
/// ```swift
/// var endpoint: URL {
///   #URL {
///     HTTPS("example.com") {
///       Path { "v1"; "items" }
///     }
///   }
/// }
/// ```
@freestanding(expression)
public macro URL(@URLRootBuilder _ content: () -> [URLDeclaration]) -> URL =
    #externalMacro(module: "URLBuilderMacros", type: "URLMacro")

/// Builds a URL from a result-builder declaration with explicit
/// configuration. Traps on invalid input.
@freestanding(expression)
public macro URL(
    configuration: URLBuildConfiguration,
    @URLRootBuilder _ content: () -> [URLDeclaration]
) -> URL = #externalMacro(module: "URLBuilderMacros", type: "URLMacro")

// MARK: - @URLQuery + @Query (peer)

/// Per-property configuration for `@URLQuery` synthesis.
public enum QueryAttribute: Sendable {
    /// Override the rendered query key for the property.
    case key(String)
    /// Render a `Bool` property as a value-less flag (`?name`) when true,
    /// omit when false.
    case flag
    /// Exclude the property from synthesis.
    case ignore
}

/// Synthesizes `URLQueryRepresentable` conformance for a struct, class,
/// or actor by walking its stored properties.
///
/// ```swift
/// @URLQuery
/// struct SearchInput {
///   let q: String
///   @Query(.key("page_number")) let page: Int?
///   let tags: [String]
///   @Query(.flag) let strict: Bool
///   @Query(.ignore) let internalTrace: UUID
/// }
/// ```
@attached(extension, conformances: URLQueryRepresentable, names: named(urlQuery))
public macro URLQuery() = #externalMacro(module: "URLBuilderMacros", type: "URLQueryMacro")

/// Configures how `@URLQuery` synthesizes a particular property.
///
/// Use one of `.key("…")`, `.flag`, or `.ignore`. The peer macro itself
/// generates no peers — it exists so Swift recognises the attribute and
/// `@URLQuery` can read it from the property's source.
@attached(peer)
public macro Query(_ attribute: QueryAttribute) =
    #externalMacro(module: "URLBuilderMacros", type: "QueryAttributeMacro")
