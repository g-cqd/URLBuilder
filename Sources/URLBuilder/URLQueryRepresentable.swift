import Foundation

/// A type that converts to a single `URLQueryValue` (the right-hand side of
/// a `key=value` query item).
///
/// The library applies the configured `QueryEncoding` and percent-encoding
/// to the produced value. Conforming types should produce a textual
/// representation that round-trips through the receiving system.
public protocol URLQueryValueConvertible {
    var urlQueryValue: URLQueryValue { get }
}

/// A type that expands to one or more `Query` items inside a URL builder.
///
/// Use this for endpoint-input DTOs that participate in URL construction
/// without requiring `Encodable`. Conforming types compose query items
/// through the `@URLQueryBuilder` result builder, which supports
/// conditionals, loops, and other Swift control-flow.
///
/// ```swift
/// struct SearchInput: URLQueryRepresentable {
///   let q: String
///   let page: Int?
///
///   @URLQueryBuilder
///   var urlQuery: [Query] {
///     Query("q", q)
///     if let page { Query("page", page) }
///   }
/// }
/// ```
public protocol URLQueryRepresentable {
    @URLQueryBuilder var urlQuery: [Query] { get }
}

// MARK: - Standard scalar conformances

extension String: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(self) }
}

extension Substring: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Bool: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(self ? "true" : "false") }
}

extension Int: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Int8: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Int16: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Int32: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Int64: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UInt: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UInt8: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UInt16: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UInt32: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UInt64: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Double: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension Float: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(String(self)) }
}

extension UUID: URLQueryValueConvertible {
    public var urlQueryValue: URLQueryValue { .value(uuidString) }
}

extension Date: URLQueryValueConvertible {
    /// Renders the date as ISO 8601 with fractional seconds in UTC.
    public var urlQueryValue: URLQueryValue {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .value(formatter.string(from: self))
    }
}

// MARK: - RawRepresentable default conformance

extension RawRepresentable where RawValue: URLQueryValueConvertible {
    /// Default `urlQueryValue` for `RawRepresentable` types whose raw value
    /// is itself `URLQueryValueConvertible`. Conforming enums opt in by
    /// declaring conformance:
    ///
    /// ```swift
    /// enum SortDirection: String, URLQueryValueConvertible {
    ///   case ascending, descending
    /// }
    /// ```
    public var urlQueryValue: URLQueryValue {
        rawValue.urlQueryValue
    }
}

// MARK: - Query convenience inits

extension Query {
    /// Creates a query item from a value conforming to BOTH
    /// `URLQueryValueConvertible` and `Encodable`.
    ///
    /// This overload exists purely to disambiguate when a value satisfies
    /// the constraints of both single-value paths below — Swift picks the
    /// most-specific overload, and this one routes through the typed
    /// `urlQueryValue` path (preferring the user's declared rendering over
    /// generic JSON encoding).
    public init<Value: URLQueryValueConvertible & Encodable & Sendable>(
        _ name: String,
        _ value: Value
    ) {
        self.init(name, value.urlQueryValue)
    }

    /// Creates a query item from any `URLQueryValueConvertible` value —
    /// rendered directly via the declared `urlQueryValue`, bypassing JSON.
    public init<Value: URLQueryValueConvertible>(_ name: String, _ value: Value) {
        self.init(name, value.urlQueryValue)
    }

    /// Creates a query item from any `Encodable` value, rendered as compact.
    ///
    /// JSON (sorted keys, slashes unescaped). For types that also conform to
    /// `URLQueryValueConvertible`, the typed overload above wins.
    public init<Value: Encodable & Sendable>(_ name: String, _ value: Value) {
        self.init(name, .encoded(value))
    }
}
