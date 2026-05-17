// =====================================================================
// RFC 9110 §4.2 — http and https URI Schemes
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc9110.txt §4.2.1 (http)
//          Documentation/References/RFCs/rfc9110.txt §4.2.2 (https)
//          Documentation/References/RFCs/rfc9110.txt §4.2.3 (normalisation)
//          Documentation/References/RFCs/rfc9110.txt §4.2.4 (deprecated userinfo)
// Scope:   §4.2.1 / §4.2.2 — `http` and `https` URI grammar:
//                            authority MUST be present, host MUST be non-empty,
//                            default ports 80 / 443.
//          §4.2.3 — case normalisation (scheme + host lowercase),
//                   default-port omission, empty-path / "/" equivalence.
//          §4.2.4 — userinfo deprecated for http(s) — covered separately
//                   in RFC3986_Userinfo.swift and SecurityComplianceTests.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 9110 §4.2 — http and https URI Schemes")
struct RFC9110HTTPSchemeTests {
    // §4.2.1 — http: default port 80
    // §4.2.2 — https: default port 443
    // §4.2.3 — default ports SHOULD be omitted from the URI
    @Test
    func `§4.2.3 — omits default HTTP and HTTPS ports`() throws {
        let httpURL = try withThrowingURL {
            HTTP("example.com") { Port(80) }
        }
        let httpsURL = try withThrowingURL {
            HTTPS("example.com") { Port(443) }
        }
        #expect(httpURL.absoluteString == "http://example.com")
        #expect(httpsURL.absoluteString == "https://example.com")
    }

    // §4.2.3 — empty path and "/" are equivalent for http(s).
    @Test
    func `§4.2.3 — absent path remains absent by DSL design`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com")
        }
        #expect(url.absoluteString == "https://example.com")
    }

    // §4.2.3 — empty path and "/" are equivalent for http(s).
    @Test
    func `§4.2.3 — explicit empty path renders as '/' for http(s)`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Path("") }
        }
        #expect(url.absoluteString == "https://example.com/")
    }

    // §4.2.3 — case-insensitive scheme + host comparison; canonical lowercase.
    @Test
    func `§4.2.3 — http(s) host case is normalised to lowercase`() throws {
        let url = try withThrowingURL { HTTPS("API.Example.COM") }
        #expect(url.absoluteString == "https://api.example.com")
    }

    // §4.2 — http and https REQUIRE a non-empty host.
    @Test
    func `§4.2 — rejects http(s) without a host`() {
        #expect(throws: URLBuildError.missingHost(scheme: "https")) {
            try withThrowingURL {
                HTTPS { Path("search") }
            }
        }
    }

    // §4.2.1 — http URI shape:
    //   "http-URI = "http" "://" authority path-abempty [ "?" query ]
    //                       [ "#" fragment ]"
    // The DSL's `HTTP(...)` declaration builds exactly this shape; the scheme
    // is fixed and lowercased.
    @Test
    func `§4.2.1 — http URI emits 'http://' authority prefix`() throws {
        let url = try withThrowingURL { HTTP("example.com") }
        #expect(url.absoluteString.hasPrefix("http://"))
        #expect(url.scheme == "http")
    }

    // §4.2.2 — https URI shape (same as http) with `https` scheme.
    @Test
    func `§4.2.2 — https URI emits 'https://' authority prefix`() throws {
        let url = try withThrowingURL { HTTPS("example.com") }
        #expect(url.absoluteString.hasPrefix("https://"))
        #expect(url.scheme == "https")
    }

    // §4.2.3 — "Both schemes ... [are] case-insensitive ... URIs that
    //           differ only in the case of these components are equivalent."
    // Pin both directions: scheme-case-insensitive on input, lowercased
    // on output; host-case-insensitive on input, lowercased on output.
    @Test
    func `§4.2.3 — uppercase scheme on input round-trips lowercase on output`() throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme("HTTPS"), host: "example.com")
        }
        #expect(url.scheme == "https")
        #expect(url.absoluteString == "https://example.com")
    }
}
