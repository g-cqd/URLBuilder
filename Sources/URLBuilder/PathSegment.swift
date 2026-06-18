import Foundation

/// A path segment declaration.
///
/// Used as the element type inside `Path { … }` builder blocks and as the
/// leaf produced by `Path` initializers.
public struct PathSegment: Hashable, Sendable, ExpressibleByStringLiteral {
    // `var` (not `let`) so the `consuming` builder steps can append in place
    // when the receiver is uniquely owned. The property stays `internal`;
    // `PathSegment` remains a value type, so value semantics and the synthesized
    // `Hashable`/`Equatable` (which compare the stored array) are unchanged.
    internal var values: [String]

    /// A trailing-slash marker.
    ///
    /// Renders as a final empty segment.
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
    ///
    /// `consuming`: a literal fluent chain such as
    /// `PathSegment.segment(a).segment(b)…` (or a `consume`-folded loop)
    /// mutates the uniquely-owned receiver in place — each intermediate is a
    /// moved temporary — so the whole chain copies O(N) elements total instead
    /// of the O(N²) that `values + [value]` per step incurred.
    public consuming func segment(_ value: String) -> PathSegment {
        appending(value)
    }

    /// Creates a path segment.
    public static func component(_ value: String) -> PathSegment {
        PathSegment(value)
    }

    /// Appends a path segment.
    public consuming func component(_ value: String) -> PathSegment {
        appending(value)
    }

    private init(values: [String]) {
        self.values = values
    }

    // `consuming` receiver: when it is uniquely owned — a literal `.segment`
    // chain, where each intermediate is a moved temporary, or a `consume`-folded
    // loop — `append` mutates the existing buffer in place instead of
    // allocating and copying the whole accumulated array, so the chain copies
    // O(N) elements total instead of O(N²). Value semantics are preserved: a
    // retained earlier `PathSegment` keeps its buffer shared, so `append`
    // copy-on-writes before mutating.
    //
    // Caveat (Swift ownership): a caller folding into a reused `var`
    // (`p = p.segment(x)` in a loop) keeps the prior value alive across the call,
    // so the buffer is non-unique at each `append` and the per-step copy
    // returns — that fold stays O(N²) unless the caller writes
    // `p = (consume p).segment(x)`. Paths built that way are uncommon (the
    // idiomatic `Path { … }` DSL is already O(N)); the unbounded-fold case is
    // not optimized here to keep the type a plain, compiler-checked `Sendable`
    // value (no `@unchecked` CoW class buffer).
    private consuming func appending(_ value: String) -> PathSegment {
        values.append(value)
        return self
    }
}
