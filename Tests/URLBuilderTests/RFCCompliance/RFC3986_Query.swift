// =====================================================================
// RFC 3986 §3.4 — Query
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.4
// Scope:   query grammar (`*( pchar / "/" / "?" )`), repeated-name
//          ordering, DSL flag-vs-empty distinction, empty-name rejection.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3986QueryTests {
    // §3.4 — query = *( pchar / "/" / "?" )
    // The reserved query-internal delimiters `&` and `=` MUST be
    // percent-encoded inside a value to keep the key/value structure
    // unambiguous when re-parsed.
    @Test
    func `§3.4 — preserves '/' and '?' in value, encodes '&' and '='`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("")
                Query("redirect", "/a?b=c&d=e")
            }
        }
        #expect(url.absoluteString == "https://example.com/?redirect=/a?b%3Dc%26d%3De")
    }

    @Test
    func `§3.4 — preserves repeated query item names and order`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("tag", "ios")
                Query("tag", "swift")
            }
        }
        #expect(url.absoluteString == "https://example.com?tag=ios&tag=swift")
    }

    // DSL convention: distinguishes flag (no `=`) from explicit empty (`=`).
    // RFC 3986 leaves this open; this DSL preserves declaration intent.
    @Test
    func `§3.4 (DSL) — distinguishes flag (?preview) from empty (?search=)`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("preview")
                Query("search", .empty)
            }
        }
        #expect(url.absoluteString == "https://example.com?preview&search=")
    }

    // DSL safety rule, not in RFC 3986: reject empty query name.
    // Empty name produces `?=value` which is ambiguous to re-parse.
    @Test
    func `(DSL) — rejects empty query name`() {
        #expect(throws: URLBuildError.emptyQueryName) {
            try withThrowingURL {
                HTTPS("example.com") { Query("", "value") }
            }
        }
    }
}
