// =====================================================================
// RFC 3986 §3.1 / RFC 7595 §3.8 — Scheme
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.1 + §6.2.2.1
//          Documentation/References/RFCs/rfc7595.txt §3.8
// Scope:   scheme ABNF, lowercase canonical form, registration syntax.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.1 / RFC 7595 §3.8 — Scheme")
struct RFC3986SchemeTests {
    // §3.1 ABNF:
    //   scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    // §6.2.2.1 Case Normalization:
    //   "the scheme and host are case-insensitive and therefore should be
    //   normalized to lowercase."
    @Test(
        arguments: [
            ("HTTP", "http"),
            ("HTTPS", "https"),
            ("foo+bar.1", "foo+bar.1"),
            ("x-y.z+1", "x-y.z+1"),
            ("MyApp", "myapp"),
        ])
    func `accepts and lowercases valid schemes`(input: String, normalized: String) throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme(input), host: "example.com")
        }
        #expect(url.scheme == normalized)
    }

    // Negative cases for §3.1: empty, digit-leading, illegal characters.
    @Test(
        arguments: ["", "1http", "+http", "ht_tp", "ht tp", ".http", "-http"])
    func `rejects schemes that violate the ABNF`(input: String) {
        #expect(throws: URLBuildError.invalidScheme(input)) {
            try withThrowingURL { URLDeclaration(scheme: Scheme(input), host: "example.com") }
        }
    }

    // RFC 7595 §3.8 — schemes are registered in lowercase form; URLComponents
    // normalises the stored value to lowercase when producing the URL.
    @Test
    func `scheme literal preserves raw case but URL is lowercased`() throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme("HTTPS"), host: "example.com")
        }
        #expect(url.scheme == "https")
    }
}
