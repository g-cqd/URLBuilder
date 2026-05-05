import Foundation

/// A path segment declaration.
///
/// Used as the element type inside `Path { … }` builder blocks and as the
/// leaf produced by `Path` initializers.
public struct PathSegment: Hashable, Sendable, ExpressibleByStringLiteral {
    internal let values: [String]

    /// A trailing-slash marker. Renders as a final empty segment.
    public static let trailingSlash = PathSegment("")

    public init(_ value: String) {
        values = [value]
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Creates a path segment.
    public static func segment(_ value: String) -> PathSegment {
        PathSegment(value)
    }

    /// Appends a path segment.
    public func segment(_ value: String) -> PathSegment {
        appending(value)
    }

    /// Creates a path segment.
    public static func component(_ value: String) -> PathSegment {
        PathSegment(value)
    }

    /// Appends a path segment.
    public func component(_ value: String) -> PathSegment {
        appending(value)
    }

    private init(values: [String]) {
        self.values = values
    }

    private func appending(_ value: String) -> PathSegment {
        PathSegment(values: values + [value])
    }
}
