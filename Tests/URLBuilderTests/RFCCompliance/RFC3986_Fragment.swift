// =====================================================================
// RFC 3986 §3.5 — Fragment
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.5
// Scope:   fragment grammar (`*( pchar / "/" / "?" )`) + space encoding.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.5 — Fragment")
struct RFC3986FragmentTests {
    // §3.5 — fragment = *( pchar / "/" / "?" )
    @Test
    func `§3.5 — preserves '/' and '?' in fragment`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Fragment("section/a?b") }
        }
        #expect(url.absoluteString == "https://example.com#section/a?b")
    }

    @Test
    func `§3.5 — percent-encodes space in fragment`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Fragment("a b") }
        }
        #expect(url.absoluteString == "https://example.com#a%20b")
    }
}
