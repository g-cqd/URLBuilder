// =====================================================================
// RFC 3986 §3.2.1 / RFC 9110 §4.2.4 — Userinfo (deprecated)
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.2.1
//          Documentation/References/RFCs/rfc9110.txt §4.2.4
// Scope:   userinfo is rejected by default, explicitly opt-in, and
//          percent-encoded from raw username/password fields. Host
//          labels containing `@` remain rejected because they would
//          smuggle userinfo through the host grammar.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.2.1 / RFC 9110 §4.2.4 — Userinfo (deprecated)")
struct RFC3986UserinfoTests {
    private static let usernameOnly = URLBuildConfiguration(userInfoPolicy: .usernameOnly)
    private static let usernameAndPassword = URLBuildConfiguration(
        userInfoPolicy: .usernameAndPassword)

    // §3.2.1 — "Use of the format 'user:password' in the userinfo field
    // is deprecated."
    // The DSL keeps userinfo disabled by default. Callers must opt in
    // per build because userinfo has credential-leak and display-spoofing
    // risk in both RFC 3986 and RFC 9110.
    @Test
    func `§3.2.1 — userinfo is disabled by default`() {
        #expect(throws: URLBuildError.userInfoDisabled) {
            try withThrowingURL {
                HTTPS("example.com") {
                    UserInfo(username: "alice")
                }
            }
        }
    }

    @Test
    func `§3.2.1 — username-only userinfo is opt-in`() throws {
        let url = try withThrowingURL(configuration: Self.usernameOnly) {
            HTTPS("example.com") {
                UserInfo(username: "alice")
            }
        }

        #expect(url.absoluteString == "https://alice@example.com")
    }

    @Test
    func `§3.2.1 — password userinfo requires explicit password policy`() {
        #expect(throws: URLBuildError.passwordUserInfoDisabled) {
            try withThrowingURL(configuration: Self.usernameOnly) {
                HTTPS("example.com") {
                    UserInfo(username: "alice", password: "secret")
                }
            }
        }
    }

    @Test
    func `§3.2.1 — username/password userinfo is opt-in`() throws {
        let url = try withThrowingURL(configuration: Self.usernameAndPassword) {
            HTTPS("example.com") {
                UserInfo(username: "alice", password: "secret")
            }
        }

        #expect(url.absoluteString == "https://alice:secret@example.com")
    }

    @Test
    func `§3.2.1 — userinfo raw fields are percent-encoded as UTF-8`() throws {
        let url = try withThrowingURL(configuration: Self.usernameAndPassword) {
            HTTPS("example.com") {
                UserInfo(username: "a:b@c/d%", password: "p:ss@/?")
            }
        }

        #expect(
            url.absoluteString == "https://a%3Ab%40c%2Fd%25:p%3Ass%40%2F%3F@example.com")
    }

    @Test
    func `§3.2.1 — empty username is rejected`() {
        #expect(throws: URLBuildError.invalidUserInfo) {
            try withThrowingURL(configuration: Self.usernameOnly) {
                HTTPS("example.com") {
                    UserInfo(username: "")
                }
            }
        }
    }

    @Test
    func `§3.2.1 — empty password is rendered explicitly`() throws {
        let url = try withThrowingURL(configuration: Self.usernameAndPassword) {
            HTTPS("example.com") {
                UserInfo(username: "alice", password: "")
            }
        }

        #expect(url.absoluteString == "https://alice:@example.com")
    }

    @Test
    func `§3.2.1 + RFC 3987 §4.1 — bidi formatting characters are rejected in userinfo`() {
        #expect(throws: URLBuildError.invalidUserInfo) {
            try withThrowingURL(configuration: Self.usernameAndPassword) {
                HTTPS("example.com") {
                    UserInfo(username: "alice", password: "sec\u{202E}ret")
                }
            }
        }
    }

    @Test
    func `§3.2 — userinfo requires an authority host`() {
        #expect(throws: URLBuildError.userInfoRequiresHost) {
            try withThrowingURL(configuration: Self.usernameOnly) {
                URLDeclaration(scheme: Scheme("example")) {
                    UserInfo(username: "alice")
                    Path("resource")
                }
            }
        }
    }

    @Test
    func `§3.2.1 — duplicate userinfo declarations are rejected`() {
        #expect(throws: URLBuildError.duplicateUserInfo) {
            try withThrowingURL(configuration: Self.usernameAndPassword) {
                HTTPS("example.com") {
                    UserInfo(username: "alice")
                    UserInfo(username: "bob")
                }
            }
        }
    }

    @Test
    func `§7.5 — userinfo validation errors do not echo secrets`() {
        #expect(URLBuildError.invalidUserInfo.description == "Invalid userinfo.")
        #expect(URLBuildError.passwordUserInfoDisabled.description.contains("secret") == false)
    }

    // §3.2.1 — A label containing '@' is rejected in the assembled-host
    // validation rather than interpreted as userinfo.
    @Test
    func `§3.2.1 — composed-host label rejects '@' (security note)`() {
        #expect(throws: (any Error).self) {
            try withThrowingURL {
                HTTPS {
                    Host {
                        .domain("user@evil")
                            .topLevelDomain(.com)
                    }
                }
            }
        }
    }
}
