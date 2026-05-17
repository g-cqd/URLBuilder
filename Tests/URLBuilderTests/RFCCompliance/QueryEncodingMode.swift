// =====================================================================
// URLBuildConfiguration — query rendering encoding
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §2.1, §3.4
//          Documentation/References/RFCs/rfc3629.txt §3 (UTF-8)
//          Documentation/References/WHATWG/url.html  §5.2
//          (`application/x-www-form-urlencoded` serializer)
//          HTML Living Standard form-urlencoded byte set
//          (alphanumeric + `*` / `-` / `.` / `_`).
// Scope:   Verifies the opt-in `URLBuildConfiguration.queryEncoding`
//          rendering toggle. The DSL's validation rules are unchanged
//          across both modes; only the on-the-wire shape of the query
//          component differs:
//            - `.rfc3986` (default) — RFC 3986 §2.1, SPACE → `%20`.
//            - `.formURLEncoded`     — WHATWG URL §5.2,  SPACE → `+`,
//                                      literal `+` → `%2B`.
//          Use case: backends or browsers that expect form-shaped
//          query strings. This is NOT advertised as full WHATWG
//          compliance; it is a targeted rendering preference.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("URLBuildConfiguration — query encoding rendering")
struct QueryEncodingModeTests {
    // -------------------------------------------------------------------
    // Default mode — RFC 3986 §2.1
    //   "If a reserved character is found in a URI component and no
    //    delimiting role is known for that character, then it MUST be
    //    interpreted as representing the data octet corresponding to
    //    that character's encoding in US-ASCII."
    //   "A percent-encoded octet is encoded as a character triplet
    //    [...] %HEXDIG HEXDIG."
    // -------------------------------------------------------------------

    @Test
    func `RFC 3986 §2.1 (default) — SPACE renders as %20 in query value`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("k", "a b") }
        }
        #expect(url.absoluteString == "https://example.com?k=a%20b")
    }

    @Test
    func `RFC 3986 §2.1 (default) — SPACE renders as %20 in query name`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("a b", "v") }
        }
        #expect(url.absoluteString == "https://example.com?a%20b=v")
    }

    @Test
    func `RFC 3986 §2.1 (default) — literal '+' is preserved as a sub-delim`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("k", "1+2") }
        }
        // RFC 3986 §3.4 includes "+" in the sub-delims set permitted in
        // query (`*( pchar / "/" / "?" )`). Foundation's RFC-3986 query
        // serializer leaves it as a literal byte.
        #expect(url.absoluteString == "https://example.com?k=1+2")
    }

    // -------------------------------------------------------------------
    // Form-URL-encoded mode — WHATWG URL Living Standard §5.2
    //   "The application/x-www-form-urlencoded percent-encode set is
    //    the component percent-encode set and U+0021 (!), U+0027 (')
    //    to U+0029 RIGHT PARENTHESIS, inclusive, and U+007E (~)."
    //   The serializer additionally maps U+0020 SPACE to U+002B (+).
    // HTML Living Standard form-urlencoded byte set (informative):
    //   bytes whose value is an alphanumeric or *, -, ., _ pass through
    //   unencoded; SPACE becomes +; everything else is %HH-encoded
    //   from the UTF-8 byte sequence (RFC 3629 §3).
    // -------------------------------------------------------------------

    private static let form = URLBuildConfiguration(queryEncoding: .formURLEncoded)

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — SPACE renders as '+' in query value`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("k", "a b") }
        }
        #expect(url.absoluteString == "https://example.com?k=a+b")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — SPACE renders as '+' in query name`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("a b", "v") }
        }
        #expect(url.absoluteString == "https://example.com?a+b=v")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — literal '+' is encoded as %2B`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("k", "1+2") }
        }
        #expect(url.absoluteString == "https://example.com?k=1%2B2")
    }

    @Test(
        arguments: [
            ("=", "%3D"),
            ("&", "%26"),
            ("?", "%3F"),
            ("#", "%23"),
            ("/", "%2F"),
            (":", "%3A"),
            ("@", "%40"),
            ("!", "%21"),
            ("$", "%24"),
            ("'", "%27"),
            ("(", "%28"),
            (")", "%29"),
            (",", "%2C"),
            (";", "%3B"),
            ("~", "%7E"),
        ]
    )
    func `WHATWG URL §5.2 (.formURLEncoded) — sub-delims and reserved chars are percent-encoded`(
        _ raw: String, _ encoded: String
    ) throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("k", "x\(raw)y") }
        }
        #expect(url.absoluteString == "https://example.com?k=x\(encoded)y")
    }

    @Test(
        arguments: [
            // U+00E9 LATIN SMALL LETTER E WITH ACUTE — UTF-8 0xC3 0xA9
            ("café", "caf%C3%A9"),
            // U+1F4A9 PILE OF POO — UTF-8 0xF0 0x9F 0x92 0xA9
            ("\u{1F4A9}", "%F0%9F%92%A9"),
            // U+4E2D CJK UNIFIED IDEOGRAPH-4E2D — UTF-8 0xE4 0xB8 0xAD
            ("中", "%E4%B8%AD"),
        ]
    )
    func `RFC 3629 §3 + WHATWG URL §5.2 — non-ASCII is encoded from its UTF-8 byte sequence`(
        _ raw: String, _ encoded: String
    ) throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("k", raw) }
        }
        #expect(url.absoluteString == "https://example.com?k=\(encoded)")
    }

    @Test(
        arguments: [
            "abcXYZ0189",  // ALPHA / DIGIT
            "*-._",  // form-encoded pass-through punctuation
            "abc-DEF.ghi_jkl",  // mixed
        ]
    )
    func `WHATWG URL §5.2 (.formURLEncoded) — pass-through bytes are unencoded`(_ raw: String)
        throws
    {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") { Query("k", raw) }
        }
        #expect(url.absoluteString == "https://example.com?k=\(raw)")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — query flag (no '=') round-trips`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") {
                Query("preview")
            }
        }
        #expect(url.absoluteString == "https://example.com?preview")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — explicit empty value renders as 'name='`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") {
                Query("search", .empty)
            }
        }
        #expect(url.absoluteString == "https://example.com?search=")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — multiple items are joined with '&'`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") {
                Query("a", "1 2")
                Query("b", "x+y")
                Query("c", "z")
            }
        }
        #expect(url.absoluteString == "https://example.com?a=1+2&b=x%2By&c=z")
    }

    @Test
    func `WHATWG URL §5.2 (.formURLEncoded) — repeated names preserve order`() throws {
        let url = try withThrowingURL(configuration: Self.form) {
            HTTPS("example.com") {
                Query("tag", "i o s")
                Query("tag", "swift")
            }
        }
        #expect(url.absoluteString == "https://example.com?tag=i+o+s&tag=swift")
    }

    // -------------------------------------------------------------------
    // Validation parity — the rendering toggle MUST NOT relax validation.
    // RFC 3986 §3.4 + RFC 9110 §11.7.6 (CRLF / header injection) — query
    // names MUST NOT contain CR/LF. Same rule under both modes.
    // -------------------------------------------------------------------

    @Test
    func `.formURLEncoded preserves CR/LF rejection in query name`() {
        #expect(throws: (any Error).self) {
            try withThrowingURL(configuration: Self.form) {
                HTTPS("example.com") { Query("bad\r\nname", "v") }
            }
        }
    }

    @Test
    func `.formURLEncoded preserves NUL rejection in query value`() {
        #expect(throws: (any Error).self) {
            try withThrowingURL(configuration: Self.form) {
                HTTPS("example.com") { Query("k", "bad\u{00}v") }
            }
        }
    }

    @Test
    func `.formURLEncoded preserves empty-name rejection`() {
        #expect(throws: URLBuildError.emptyQueryName) {
            try withThrowingURL(configuration: Self.form) {
                HTTPS("example.com") { Query("", "v") }
            }
        }
    }
}
