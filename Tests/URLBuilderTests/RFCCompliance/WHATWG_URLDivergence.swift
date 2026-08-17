// =====================================================================
// WHATWG URL Standard — divergence pins
// ---------------------------------------------------------------------
// Spec:    docs/References/WHATWG/url.html  (living standard)
//          docs/References/RFCs/rfc3986.txt (RFC URI grammar)
// Scope:   The DSL targets RFC 3986 / 3987 / 5891.  The WHATWG URL
//          living standard documents browser-oriented behaviours that
//          deliberately differ from the RFC grammar (lenient backslash
//          handling, control-character mapping, application/x-www-form-
//          urlencoded for query, etc.).  These tests pin the DSL's
//          stricter RFC-compliant behaviour so a future "be like the
//          browser" refactor would be flagged immediately.
// =====================================================================

import AemiTestKit
import Foundation
import Testing
import URLBuilder

struct WHATWGURLDivergenceTests {
    // WHATWG: backslash in path is normalised to forward slash for
    // "special" schemes (http/https/ws/wss/ftp/file).
    // RFC 3986 §3.3:  pchar does NOT include "\".  The DSL rejects.
    @Test
    func `RFC 3986 §3.3 — rejects backslash in path segment (vs. WHATWG normalises)`() {
        #expect(throws: URLBuildError.invalidPathSegment(#"a\b"#)) {
            try withThrowingURL { HTTPS("example.com") { Path(#"a\b"#) } }
        }
    }

    // WHATWG: tabs and newlines in input are silently removed before
    // parsing.  RFC 3986 §2 has no such relaxation; controls are not
    // members of unreserved / reserved / pct-encoded.
    @Test(
        arguments: ["a\tb", "a\nb", "a\rb"])
    func `RFC 3986 §2 — rejects ASCII control characters (vs. WHATWG strips them)`(segment: String) {
        #expect(throws: URLBuildError.invalidPathSegment(segment)) {
            try withThrowingURL { HTTPS("example.com") { Path(segment) } }
        }
    }

    // WHATWG: query string is encoded with the
    // application/x-www-form-urlencoded encode set, which percent-encodes
    // SPACE to '+'.  RFC 3986 §2.1 percent-encodes SPACE to "%20".  The
    // DSL follows the RFC.
    @Test
    func `RFC 3986 §2.1 — encodes SPACE as %20 in query (vs. WHATWG '+')`() throws {
        let url: URL = try withThrowingURL { HTTPS("example.com") { Query("k", "a b") } }
        let absoluteString = url.absoluteString
        let containsPercent20 = absoluteString.contains("k=a%20b")
        let containsPlus = absoluteString.contains("k=a+b")
        #expect(containsPercent20)
        #expect(containsPlus == false)
    }

    // WHATWG serializers commonly normalize an absent special-scheme path
    // to "/". Requirements §10 locks URLBuilder's distinction between an
    // absent path and an explicitly declared empty path.
    @Test
    func `RFC 9110 §4.2.3 — keeps absent http(s) path absent (vs. WHATWG-style slash)`() throws {
        let url: URL = try withThrowingURL { HTTPS("example.com") }
        let absoluteString = url.absoluteString
        #expect(absoluteString == "https://example.com")
    }

    // WHATWG: lone surrogates and non-scalar codepoints are replaced
    // with U+FFFD.  RFC 3987 + RFC 5892 §2.4 reject them outright in
    // host labels.
    @Test
    func `RFC 5892 §2.4 — rejects U+FFFD substitution in host`() {
        // U+FFFD itself is general-category So → DISALLOWED.
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{FFFD}bar", .com) }
        } where: { (error: URLBuildError) in
            // U+FFFD is general-category So → DISALLOWED → rejected as an invalid host.
            if case .invalidHost = error { true } else { false }
        }
    }
}
