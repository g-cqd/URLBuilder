// =====================================================================
// URLBuilderTests — DSL ergonomics
//
// This file exercises DSL behaviours that are NOT direct RFC clauses
// (result-builder shape, instance/static API parity, conditionals,
// optional bindings). Tests that DO map to an RFC clause are also
// re-asserted in `RFCComplianceTests.swift` with full citations.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("URLBuilder — DSL ergonomics")
struct URLBuilderTests {
    /// RFC 3986 §3 — single URI per declaration.
    ///
    /// RFC 3986 §3.4 query.
    /// IRI percent-encoding for "some value" → "some%20value" per §2.1.
    @Test
    func `builds the SwiftUI-style declaration from the README`() {
        let url: URL = URLBuilder {
            HTTPS {
                Subdomain("www")
                Domain("apple")
                TLD.com
                Query("search", "some value")
            }
        }

        #expect(url.absoluteString == "https://www.apple.com?search=some%20value")
    }

    /// RFC 3986 §3.3 path segment grammar; §2.1 percent-encoding of space.
    @Test
    func `appends path segments and percent-encodes reserved content`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host("api.apple.com")
                Path {
                    "v1"
                    "shared tickets"
                }
            }
        }

        #expect(url.absoluteString == "https://api.apple.com/v1/shared%20tickets")
    }

    /// RFC 3986 §3.4 — query syntax does not forbid repeated names; the
    /// DSL preserves order via URLComponents.queryItems.
    @Test
    func `preserves repeated query item names`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
                Query("tag", "ios")
                Query("tag", "swift")
            }
        }

        #expect(url.absoluteString == "https://apple.com?tag=ios&tag=swift")
    }

    /// DSL convention beyond RFC 3986 §3.4: distinguishes flag (`?preview`,
    /// no `=`) from explicit empty value (`?search=`).
    @Test
    func `distinguishes query flags from empty values`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
                Query("preview")
                Query("search", .empty)
            }
        }

        #expect(url.absoluteString == "https://apple.com?preview&search=")
    }

    /// RFC 9110 §4.2.1 (HTTP default port 80) + §4.2.2 (HTTPS default
    /// port 443) + §4.2.3 (omit default port from URI).
    @Test
    func `normalizes default http and https ports`() throws {
        let httpsURL = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
                Port(443)
            }
        }

        let httpURL = try withThrowingURL {
            HTTP {
                Domain("apple")
                TLD.com
                Port(80)
            }
        }

        #expect(httpsURL.absoluteString == "https://apple.com")
        #expect(httpURL.absoluteString == "http://apple.com")
    }

    /// RFC 3986 §3.2.3 — port = *DIGIT.
    ///
    /// Non-default ports are preserved.
    @Test
    func `supports non-default ports`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
                Port(8443)
            }
        }

        #expect(url.absoluteString == "https://apple.com:8443")
    }

    /// RFC 3986 §3 — `URI = scheme ":" hier-part [ ...
    ///
    /// ]`. With no
    /// authority, hier-part is path-rootless / path-absolute / path-empty.
    /// RFC 7595 §3.8 — custom schemes follow the same syntactic rules.
    @Test
    func `supports custom schemes without authority`() throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme("apple")) {
                Path("tickets", "123")
            }
        }

        #expect(url.absoluteString == "apple:tickets/123")
    }

    /// RFC 3986 §3.2 — port appears only in `authority` component;
    /// authority requires a host.
    @Test
    func `rejects ports without hosts`() {
        #expect(throws: URLBuildError.portRequiresHost) {
            try withThrowingURL {
                URLDeclaration(scheme: Scheme("apple")) {
                    Port(123)
                }
            }
        }
    }

    /// RFC 3986 §3.2.2 IP-literal grammar.
    ///
    /// RFC 4291 §2.2 IPv6 text.
    /// RFC 5952 — canonical text form.
    @Test
    func `supports IPv6 hosts`() throws {
        let url = try withThrowingURL {
            HTTPS {
                IPv6("2001:db8::1")
            }
        }

        #expect(url.absoluteString == "https://[2001:db8::1]")
    }

    /// RFC 4291 §2.2 — only valid IPv6 text forms are accepted.
    @Test
    func `rejects invalid IPv6 hosts`() {
        #expect(throws: URLBuildError.invalidIPv6Address("not:ipv6")) {
            try withThrowingURL {
                HTTPS {
                    IPv6("not:ipv6")
                }
            }
        }
    }

    /// RFC 3987 §3.1 IRI-to-URI mapping.
    ///
    /// RFC 5891 §4 IDNA lookup
    /// processing — U-label converted to A-label (Punycode).
    /// Backed by ISO/IEC 10646 (Unicode UCS) via RFC 5892.
    @Test
    func `supports IDN host declarations through Foundation normalization`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("exämple")
                TLD.com
            }
        }

        #expect(url.absoluteString == "https://xn--exmple-cua.com")
    }

    /// RFC 9110 §4.2.2 — `https` URI requires a non-empty host.
    @Test
    func `rejects missing https host`() {
        #expect(throws: URLBuildError.missingHost(scheme: "https")) {
            try withThrowingURL {
                HTTPS {
                    Path("search")
                }
            }
        }
    }

    /// RFC 3986 §3.2.2 — host is exactly one syntactic unit.
    @Test
    func `rejects conflicting host declarations`() {
        #expect(throws: URLBuildError.conflictingHostDeclarations) {
            try withThrowingURL {
                HTTPS {
                    Host("apple.com")
                    Domain("apple")
                    TLD.com
                }
            }
        }
    }

    /// RFC 3986 §3.1 — scheme ABNF rejects digit-leading.
    @Test
    func `rejects invalid schemes`() {
        #expect(throws: URLBuildError.invalidScheme("1https")) {
            try withThrowingURL {
                URLDeclaration(scheme: Scheme("1https")) {
                    Host("apple.com")
                }
            }
        }
    }

    /// RFC 1035 §2.3.1 — DNS labels MUST start with a letter (or digit
    /// per RFC 1123) and MUST NOT start with a hyphen.
    @Test
    func `rejects invalid host labels`() {
        #expect(throws: URLBuildError.invalidHostLabel("-apple")) {
            try withThrowingURL {
                HTTPS {
                    Domain("-apple")
                    TLD.com
                }
            }
        }
    }

    /// RFC 3986 §5.2.4 Remove Dot Segments — `..` is a traversal marker;
    /// the DSL rejects literal forms at construction time.
    @Test
    func `rejects traversal path segments`() {
        #expect(throws: URLBuildError.invalidPathSegment("..")) {
            try withThrowingURL {
                HTTPS {
                    Domain("apple")
                    TLD.com
                    Path("..")
                }
            }
        }
    }

    /// DSL ergonomics (no RFC mapping) — result-builder must support
    /// `if`/`for` over component declarations.
    @Test
    func `supports conditionals and loops inside builders`() throws {
        let includeWWW = true
        let queryItems = ["ios", "swift"]

        let url = try withThrowingURL {
            HTTPS {
                if includeWWW {
                    Subdomain("www")
                }
                Domain("apple")
                TLD.com
                for item in queryItems {
                    Query("tag", item)
                }
            }
        }

        #expect(url.absoluteString == "https://www.apple.com?tag=ios&tag=swift")
    }
}
