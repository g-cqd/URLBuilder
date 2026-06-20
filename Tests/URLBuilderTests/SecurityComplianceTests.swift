// =====================================================================
// SecurityComplianceTests
// ---------------------------------------------------------------------
// Pins security-relevant behaviours of the DSL. Each section covers
// a distinct injection or spoofing surface and cites the RFC clause
// that motivates the rejection or acceptance.
//
// RFC text quoted from local copies in
// `Documentation/References/RFCs/`.
// =====================================================================

import ADTestKit
import Foundation
import Testing
import URLBuilder

// MARK: - High-risk behaviours

struct SecurityHighSeverityTests {
    // -------------------------------------------------------------------
    // Host string `@` injection bypasses userinfo omission
    //
    // RFC 3986 §3.2.1 (Userinfo)
    //   "Use of the format 'user:password' in the userinfo field is
    //   deprecated. […] Applications should not render as clear text any
    //   data after the first colon […] unless the data after the colon is
    //   the empty string."
    //
    // RFC 9110 §4.2.4 — userinfo in `http(s)` URIs is deprecated.
    //
    // The DSL rejects userinfo by default and only emits it through
    // explicit userinfo declarations plus URLBuildConfiguration opt-in.
    // Passing a host containing `@` should still be rejected because it
    // would smuggle userinfo through the host grammar.
    // -------------------------------------------------------------------
    // Foundation's URLComponents round-trip rejects `@` in the host
    // component, so the DSL never returns a URL whose authority contains
    // undeclared userinfo — honouring the README guarantee.
    @Test
    func `rejects at-sign in host string`() {
        expectThrows {
            try withThrowingURL { HTTPS("attacker@evil.com") }
        } where: { (error: URLBuildError) in
            error == .invalidHost("attacker@evil.com")
        }
    }

    @Test
    func `rejects userinfo prefix in host string`() {
        expectThrows {
            try withThrowingURL { HTTPS("user:pass@evil.com") }
        } where: { (error: URLBuildError) in
            error == .invalidHost("user:pass@evil.com")
        }
    }

    @Test
    func `rejects explicit userinfo without opt-in`() {
        #expect(throws: URLBuildError.userInfoDisabled) {
            try withThrowingURL {
                HTTPS("example.com") {
                    UserInfo(username: "alice", password: "secret")
                }
            }
        }
    }

    @Test
    func `explicit userinfo percent-encodes authority delimiters`() throws {
        let configuration = URLBuildConfiguration(userInfoPolicy: .usernameAndPassword)
        let url = try withThrowingURL(configuration: configuration) {
            HTTPS("example.com") {
                UserInfo(username: "alice@example.com", password: "sec/ret")
            }
        }

        #expect(url.absoluteString == "https://alice%40example.com:sec%2Fret@example.com")
    }

    // -------------------------------------------------------------------
    // Scheme confusion: dangerous schemes are accepted
    //
    // RFC 3986 §3.1 (Scheme): syntactic only — no semantic filter.
    // RFC 7595 §3.8 — registration guidelines do not forbid javascript/data.
    //
    // The DSL intentionally allows arbitrary schemes for app deep-links
    // and custom URIs. This test pins the current behaviour so the
    // contract is explicit if a denylist is added later.
    // -------------------------------------------------------------------
    @Test(
        arguments: ["javascript", "data", "vbscript", "about", "file"])
    func `accepts dangerous browser-executable schemes`(scheme dangerous: String) throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme(dangerous), host: "victim.example")
        }
        #expect(url.scheme == dangerous)
        // If a future denylist lands, change this to
        // `#expect(throws: URLBuildError.invalidScheme(...))`.
    }

    // -------------------------------------------------------------------
    // C0 control characters (\r, \n, \t, …) in host
    //
    // RFC 3986 §2 (Characters): only unreserved + reserved + pct-encoded
    // sets are allowed. C0 controls (U+0000–U+001F) are not members of
    // any of these sets. In a host component they have no valid encoded
    // form and MUST be rejected.
    //
    // Threat: CRLF in a host string can split an HTTP/1.1 Host header.
    //
    // Foundation's URLComponents rejects interior CR/LF/TAB during the
    // round-trip, so the DSL incidentally rejects them. This test pins
    // that mitigation.
    // -------------------------------------------------------------------
    @Test(
        arguments: [
            "evil.com\r\nX-Injected: 1",
            "evil.com\nx",
            "evil\tcom"
        ])
    func `rejects C0 controls in host string`(host: String) {
        expectThrows {
            try withThrowingURL { HTTPS(host) }
        } where: { (error: URLBuildError) in
            // CR/LF/TAB in a host is rejected during validation; the rejecting clause (and so
            // the associated value) varies by control character, so match the case.
            if case .invalidHost = error { true } else { false }
        }
    }

    // -------------------------------------------------------------------
    // C0 control characters in query name / value
    //
    // RFC 3986 §3.4 (Query) limits query to pchar / "/" / "?". The pchar
    // set excludes C0 controls.
    //
    // Threat: CRLF in a query value can split a percent-decoded form body
    // when a downstream library re-uses the URL string verbatim.
    // -------------------------------------------------------------------
    @Test
    func `rejects C0 controls in query name`() {
        expectThrows {
            try withThrowingURL {
                HTTPS("example.com") {
                    Query("name\r\nX-Injected: 1", "value")
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidQueryName("name\r\nX-Injected: 1")
        }
    }

    @Test
    func `rejects C0 controls in query value`() {
        expectThrows {
            try withThrowingURL {
                HTTPS("example.com") {
                    Query("name", "value\r\nX-Injected: 1")
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidQueryValue(name: "name", value: "value\r\nX-Injected: 1")
        }
    }

    // -------------------------------------------------------------------
    // C0 control characters in fragment
    //
    // RFC 3986 §3.5 (Fragment) limits fragment to pchar / "/" / "?".
    // Same reasoning as the query surface above.
    // -------------------------------------------------------------------
    @Test
    func `rejects C0 controls in fragment`() {
        expectThrows {
            try withThrowingURL {
                HTTPS("example.com") {
                    Fragment("section\r\nX-Injected: 1")
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidFragment("section\r\nX-Injected: 1")
        }
    }
}

// MARK: - Medium-risk behaviours

struct SecurityMediumSeverityTests {
    // -------------------------------------------------------------------
    // Percent-encoded dot segments bypass traversal rejection
    //
    // RFC 3986 §5.2.4 (Remove Dot Segments) treats `.` and `..` as
    // logical traversal markers. Many HTTP servers normalise after URL
    // decoding, so `%2e%2e` is equivalent to `..` server-side.
    //
    // RFC 6943 §3.4 — identifier comparison must consider percent-decoded
    // forms when security depends on equivalence.
    // -------------------------------------------------------------------
    @Test(
        arguments: ["%2e%2e", "%2E%2E", "%2e", "%2E", "%2e%2e%2f.."])
    func `rejects percent-encoded dot segments`(segment: String) {
        expectThrows {
            try withThrowingURL {
                HTTPS("example.com") {
                    Path(segment)
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidPathSegment(segment)
        }
    }

    // -------------------------------------------------------------------
    // `%` accepted inside IPvFuture literal
    //
    // RFC 3986 §3.2.2 ABNF:
    //   IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
    // The unreserved + sub-delims sets do NOT include `%`; percent-
    // encoding is not permitted inside IP-literal brackets.
    //
    // Foundation rejects the bracketed literal during round-trip because
    // `%` is not a valid IP-literal character. Pinned to detect regressions.
    // -------------------------------------------------------------------
    @Test
    func `rejects percent sign inside IPvFuture literal`() {
        expectThrows {
            try withThrowingURL {
                HTTPS {
                    IPLiteral("v1.a%3Ab")
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidIPLiteral("v1.a%3Ab")
        }
    }

    // -------------------------------------------------------------------
    // Embedded `/` in path segment
    //
    // RFC 3986 §3.3 segment grammar disallows `/` inside a segment.
    // Each variadic argument to `Path` is a single segment; pre-joined
    // paths must fail.
    // -------------------------------------------------------------------
    @Test
    func `rejects slash in path segment`() {
        #expect(throws: URLBuildError.invalidPathSegment("tickets/123")) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Path("tickets/123")
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // No length limits (except DNS-name 253 and DNS-label 63)
    //
    // RFC 3986 §2 imposes no upper bound. RFC 1035 imposes the DNS limits.
    // This test pins the current behaviour: a 1 MiB query value succeeds.
    // If limits are added later, replace with a reject test.
    // -------------------------------------------------------------------
    @Test
    func `accepts oversized query values`() throws {
        let oversizedLength = 1_048_576
        let oversized = String(repeating: "a", count: oversizedLength)
        let url: URL = try withThrowingURL {
            HTTPS("example.com") {
                Query("k", oversized)
            }
        }
        let queryString = try #require(url.query)
        #expect(queryString.hasPrefix("k="))
        #expect(queryString.count == oversizedLength + 2)
    }
}

// MARK: - Low-risk behaviours

struct SecurityLowSeverityTests {
    // -------------------------------------------------------------------
    // Port 0 is reserved
    //
    // RFC 6335 §6 — Port 0 is reserved and MUST NOT be assigned.
    // RFC 9110 §4.2.2 — port for `http(s)` is the TCP port; clients
    // cannot connect to port 0.
    // -------------------------------------------------------------------
    @Test
    func `rejects port zero`() {
        #expect(throws: URLBuildError.invalidPort(0)) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Port(0)
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // `:` not in scheme allowed-set
    //
    // RFC 3986 §3.1 — scheme ABNF: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    // Locked in to prevent regression.
    // -------------------------------------------------------------------
    @Test
    func `rejects colon in scheme`() {
        #expect(throws: URLBuildError.invalidScheme("ht:tp")) {
            try withThrowingURL { URLDeclaration(scheme: Scheme("ht:tp"), host: "example.com") }
        }
    }
}

// MARK: - Informational behaviours

struct SecurityInfoTests {
    // -------------------------------------------------------------------
    // JSON `withoutEscapingSlashes` leaves `/` literal in Encodable query
    // values. Within RFC 3986 §3.4: `/` is allowed in query (pchar | "/" |
    // "?"). Documented to prevent regression.
    // -------------------------------------------------------------------
    private struct PathLikeValue: Codable, Sendable { let path: String }

    @Test
    func `preserves slash in JSON-encoded query value`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("filter", PathLikeValue(path: "/etc/passwd"))
            }
        }
        // Slash is preserved (URL-allowed); braces and quotes percent-encoded.
        #expect(
            url.absoluteString == "https://example.com?filter=%7B%22path%22:%22/etc/passwd%22%7D")
    }
}

// MARK: - Correctness regressions with security impact

struct SecurityCorrectnessRegressionTests {
    // -------------------------------------------------------------------
    // `invalidURLComponents` catch-all error path
    //
    // A custom scheme with no authority, where the first path segment
    // contains a colon, makes URLComponents.url == nil.
    //
    // RFC 3986 §3.3 — "the first segment cannot contain a colon (':')
    // character" when there is no authority and the path is path-noscheme.
    // -------------------------------------------------------------------
    @Test
    func `exercises invalidURLComponents path for path-noscheme`() {
        #expect(throws: URLBuildError.invalidURLComponents) {
            try withThrowingURL {
                URLDeclaration(scheme: Scheme("mailto")) {
                    Path("foo:bar")
                }
            }
        }
    }
}
