import Foundation

/// Builds a URL with a result-builder declaration.
///
/// Invalid declarations trap because this overload is intended for static,
/// SwiftUI-style URL declarations. Use `withThrowingURL` when invalid input
/// should be handled at runtime.
// swift-format-ignore: AlwaysUseLowerCamelCase
public func URLBuilder(@URLRootBuilder _ content: () -> [URLDeclaration]) -> URL {
    URLBuilder(configuration: .default, content)
}

/// Builds a URL with an explicit configuration.
///
/// Traps on invalid input.
// swift-format-ignore: AlwaysUseLowerCamelCase
public func URLBuilder(
    configuration: URLBuildConfiguration,
    @URLRootBuilder _ content: () -> [URLDeclaration]
) -> URL {
    do {
        return try withThrowingURL(configuration: configuration, content)
    } catch {
        preconditionFailure("Invalid URL declaration: \(error)")
    }
}

/// Builds a URL with a result-builder declaration and reports validation errors.
public func withThrowingURL(
    @URLRootBuilder _ content: () -> [URLDeclaration]
) throws(URLBuildError) -> URL {
    try withThrowingURL(configuration: .default, content)
}

/// Builds a URL with an explicit configuration and reports validation errors.
public func withThrowingURL(
    configuration: URLBuildConfiguration,
    @URLRootBuilder _ content: () -> [URLDeclaration]
) throws(URLBuildError) -> URL {
    let declarations = content()

    guard declarations.isEmpty == false else {
        throw .missingRootURL
    }

    guard declarations.count == 1, let declaration = declarations.first else {
        throw .multipleRootURLs
    }

    return try declaration.build(configuration: configuration)
}
