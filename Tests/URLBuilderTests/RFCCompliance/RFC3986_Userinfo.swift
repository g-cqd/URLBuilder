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

import ADTestKit
import Foundation
import Testing
import URLBuilder

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

    // §3.2.1 — userinfo = *( unreserved / pct-encoded / sub-delims / ":" ).
    // BUG 2 — the sub-delims `! $ & ' ( ) * + , ; =` are allowed unencoded, so a
    // legitimate `user!name` is preserved rather than over-encoded to
    // `user%21name`. The password subcomponent carries sub-delims unencoded too.
    @Test
    func `§3.2.1 — sub-delims in userinfo are preserved, not percent-encoded`() throws {
        let url = try withThrowingURL(configuration: Self.usernameAndPassword) {
            HTTPS("example.com") {
                UserInfo(username: "user!name", password: "a$b&c'd(e)f*g+h,i;j=k")
            }
        }

        #expect(
            url.absoluteString
                == "https://user!name:a$b&c'd(e)f*g+h,i;j=k@example.com")
    }

    // §3.2.1 — unreserved set stays unencoded alongside sub-delims.
    @Test
    func `§3.2.1 — unreserved characters in userinfo stay unencoded`() throws {
        let url = try withThrowingURL(configuration: Self.usernameOnly) {
            HTTPS("example.com") {
                UserInfo(username: "Az09-._~")
            }
        }

        #expect(url.absoluteString == "https://Az09-._~@example.com")
    }

    // §3.2.1 — `:` is the user:password separator; this encoder runs once per
    // subcomponent, so a literal `:` inside a field MUST stay percent-encoded
    // (`%3A`) and not be read as the delimiter. `@`, `/`, `?`, `%` likewise stay
    // encoded — they are gen-delims outside the userinfo sub-delims set.
    @Test
    func `§3.2.1 — gen-delims and ':' inside a userinfo field are still encoded`() throws {
        let url = try withThrowingURL(configuration: Self.usernameAndPassword) {
            HTTPS("example.com") {
                UserInfo(username: "a:b@c/d%e?f", password: "x:y")
            }
        }

        #expect(
            url.absoluteString
                == "https://a%3Ab%40c%2Fd%25e%3Ff:x%3Ay@example.com")
    }

    // §3.2.1 + RFC 3987 §4.1 — a genuinely-illegal userinfo character (a C0
    // control) is still rejected even though the allowed set widened to include
    // sub-delims.
    @Test
    func `§3.2.1 — control characters in userinfo are still rejected`() {
        #expect(throws: URLBuildError.invalidUserInfo) {
            try withThrowingURL(configuration: Self.usernameAndPassword) {
                HTTPS("example.com") {
                    UserInfo(username: "bad\u{0001}name")
                }
            }
        }
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
        // Codify the no-bare-`Error.self` discipline: require the *typed* error and the
        // exact case, with the offending label echoed (so a different rejection — or a
        // silent acceptance that smuggles userinfo through the host grammar — fails).
        expectThrows({
            try withThrowingURL {
                HTTPS {
                    Host {
                        .domain("user@evil")
                            .topLevelDomain(.com)
                    }
                }
            }
        }, where: { (error: URLBuildError) in
            // The composed host is rejected as a whole (`invalidHost`), not per-label —
            // the assembled-host validation the comment above describes.
            guard case .invalidHost(let host) = error else { return false }
            return host.contains("user@evil")
        })
    }
}
