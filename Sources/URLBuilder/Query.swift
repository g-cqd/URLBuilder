import Foundation

/// A query value declaration.
public struct URLQueryValue: Sendable, ExpressibleByStringLiteral {
    internal enum Storage: Sendable {
        case flag
        case value(String)
        case encoded(@Sendable () throws -> String)
    }

    internal let storage: Storage

    /// A query item with no `=` value, such as `?preview`.
    public static let flag = URLQueryValue(storage: .flag)

    /// A query item with an explicit empty value, such as `?search=`.
    public static let empty = URLQueryValue(storage: .value(""))

    /// A query item with a string value.
    public static func value(_ value: String) -> URLQueryValue {
        URLQueryValue(storage: .value(value))
    }

    /// A query item with an encodable value.
    ///
    /// Encodable values render as compact JSON with sorted keys and
    /// unescaped slashes. JSON strings are unwrapped to their scalar
    /// content; other values keep their JSON literal/object form.
    public static func encoded<Value: Encodable & Sendable>(_ value: Value) -> URLQueryValue {
        URLQueryValue(storage: .encoded { try URLQueryValueEncoder.encode(value) })
    }

    public init(stringLiteral value: String) {
        self = .value(value)
    }

    private init(storage: Storage) {
        self.storage = storage
    }

    internal func rawValue(name: String) throws(URLBuildError) -> String? {
        switch storage {
            case .flag:
                return nil
            case .value(let value):
                return value
            case .encoded(let encode):
                do {
                    return try encode()
                } catch {
                    throw .invalidQueryValueEncoding(name: name)
                }
        }
    }
}

/// A query item declaration.
public struct Query: Sendable {
    internal struct Item: Sendable {
        let name: String
        let value: URLQueryValue
    }

    internal let items: [Item]

    /// Creates a query item with no `=` value (a flag, like `?preview`).
    public init(_ name: String) {
        items = [Item(name: name, value: .flag)]
    }

    /// Creates a query item with a string value.
    public init(_ name: String, _ value: String) {
        items = [Item(name: name, value: .value(value))]
    }

    /// Creates a query item with an explicit query value mode.
    ///
    /// Use `URLQueryValue.flag` for value-less query items (`?preview`) and
    /// `URLQueryValue.empty` for explicit empty values (`?search=`). Typed
    /// values participate via the `URLQueryValueConvertible` and `Encodable`
    /// overloads in `URLQueryRepresentable.swift`.
    public init(_ name: String, _ value: URLQueryValue) {
        items = [Item(name: name, value: value)]
    }

    internal init(items: [Item]) {
        self.items = items
    }
}
