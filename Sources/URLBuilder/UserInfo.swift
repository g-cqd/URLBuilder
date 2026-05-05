import Foundation

/// A userinfo declaration for URI authority components.
///
/// Userinfo is disabled by default. Pass a configuration whose
/// `userInfoPolicy` permits the declared shape before building a URL.
public struct UserInfo: Sendable, Equatable {
    public let username: String
    public let password: String?

    /// Creates a username-only userinfo declaration.
    public init(username: String) {
        self.username = username
        password = nil
    }

    /// Creates a username/password userinfo declaration.
    ///
    /// RFC 3986 permits this syntax but deprecates password-style
    /// userinfo. Prefer `URLCredential` for HTTP authentication unless a
    /// scheme or legacy integration explicitly requires credentials in
    /// the URI authority.
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    /// Creates a username-only userinfo declaration.
    public static func username(_ username: String) -> UserInfo {
        UserInfo(username: username)
    }
}
