// =====================================================================
// ShorthandTests — DSL shorthand and Encodable query values
//
// Most tests here exercise DSL shape (typed host components and
// alternate result-builder forms). Where a test
// touches an RFC-defined behaviour, the RFC clause is cited above the
// `@Test`. Encodable query rendering is governed by:
//   • RFC 3986 §3.4 — query syntax
//   • DSL convention — JSON shape via `URLQueryValueEncoder`
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct ShorthandTests {
    private enum SortDirection: String, Codable, Sendable, URLQueryValueConvertible {
        case descending = "desc"
    }

    private struct SearchFilter: Codable, Sendable {
        let page: Int
        let status: String
    }

    private struct BrokenQueryValue: Encodable, Sendable {
        func encode(to encoder: any Encoder) throws {
            throw EncodingError.invalidValue(
                "broken",
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Intentional test failure"
                )
            )
        }
    }

    /// RFC 3986 §3 full URI: scheme + authority (host) + path + query +.
    ///
    /// fragment. This is the integration shape the DSL is designed for.
    @Test
    func `builds a compact typed host, path, query, and fragment declaration`() {
        let url: URL = URLBuilder {
            HTTPS {
                Host {
                    .subdomain("www")
                        .domain("apple")
                        .topLevelDomain(.com)
                }
                Path("tickets", "123")
                Query("search", "some value")
                Fragment("results")
            }
        }

        #expect(
            url.absoluteString == "https://www.apple.com/tickets/123?search=some%20value#results")
    }

    /// RFC 3986 §3.2.2 — accepts a pre-assembled reg-name string.
    @Test
    func `keeps complete host strings as an escape hatch`() throws {
        let url = try withThrowingURL {
            HTTPS("www.apple.com") {
                Path("tickets", "123")
            }
        }

        #expect(url.absoluteString == "https://www.apple.com/tickets/123")
    }

    @Test
    func `builds a compact composed host declaration`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .subdomain("www")
                        .domain("apple")
                        .topLevelDomain(.com)
                }
                Port(443)
                Query("preview")
                Query("search", .empty)
            }
        }

        #expect(url.absoluteString == "https://www.apple.com?preview&search=")
    }

    @Test
    func `builds compact nested path and query declarations`() throws {
        let builtURL = try withThrowingURL {
            URLDeclaration(scheme: Scheme("apple")) {
                Path {
                    "tickets"
                    "123"
                    PathSegment.trailingSlash
                }
                Query("tag", "ios")
                Query("tag", "swift")
                Query("preview")
                Query("search", .empty)
            }
        }

        #expect(builtURL.absoluteString == "apple:tickets/123/?tag=ios&tag=swift&preview&search=")
    }

    /// RFC 7595 §3.8 + RFC 3986 §3.1 — custom scheme `git+ssh` matches.
    ///
    /// the scheme ABNF. Lowercased per RFC 3986 §6.2.2.1.
    @Test
    func `builds custom scheme declarations with an authority`() throws {
        let url = try withThrowingURL {
            URLDeclaration(scheme: Scheme("git+ssh"), host: "Example.COM") {
                Path("apple", "URLBuilder.git")
            }
        }

        #expect(url.absoluteString == "git+ssh://example.com/apple/URLBuilder.git")
    }

    @Test
    func `builds concise label-based hosts`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .subdomain("api")
                        .domain("apple")
                        .topLevelDomain(.com)
                }
                Path("v1")
                Query("page", 2)
            }
        }

        #expect(url.absoluteString == "https://api.apple.com/v1?page=2")
    }

    @Test
    func `builds a host, path, and query with dedicated result builders`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    "www"
                    "apple"
                    TLD.com
                }
                Path {
                    "tickets"
                    "123"
                }
                Query("search", "some value")
                Query("preview")
                Query("page", 2)
            }
        }

        #expect(
            url.absoluteString
                == "https://www.apple.com/tickets/123?search=some%20value&preview&page=2")
    }

    /// RFC 3986 §3.4 — query allows pchar/`/`/`?`.
    ///
    /// Structured Encodable
    /// values are rendered as compact JSON; URLComponents percent-encodes
    /// `{`, `}`, `"` per §2.2 (reserved gen-delims and sub-delims).
    @Test
    func `encodes typed query values through Encodable conformance`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("page", 2)
                Query("active", true)
                Query("sort", SortDirection.descending)
                Query("filter", SearchFilter(page: 2, status: "open"))
            }
        }

        #expect(
            url.absoluteString
                == "https://example.com?page=2&active=true&sort=desc&filter=%7B%22page%22:2,%22status%22:%22open%22%7D"
        )
    }

    @Test
    func `reports failed Encodable query value encoding`() {
        #expect(throws: URLBuildError.invalidQueryValueEncoding(name: "broken")) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Query("broken", BrokenQueryValue())
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // Encodable scalar rendering matrix
    //
    // RFC 3986 §3.4 query allows scalar text. The DSL routes Encodable
    // values through JSONEncoder with `withoutEscapingSlashes`, then
    // unwraps JSON-string quoting. Tests below pin observable rendering
    // for each scalar kind so a future refactor is a deliberate API change.
    // -------------------------------------------------------------------

    @Test(arguments: [(true, "true"), (false, "false")])
    func `Encodable Bool renders as true or false`(value: Bool, expected: String) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("flag", value)
            }
        }
        #expect(url.absoluteString == "https://example.com?flag=\(expected)")
    }

    @Test(arguments: [0, 1, -1, Int.max, Int.min])
    func `Encodable Int renders as decimal literal`(value: Int) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("n", value)
            }
        }
        #expect(url.absoluteString == "https://example.com?n=\(value)")
    }

    /// Double rendering goes through JSON; this pins the current behaviour
    /// so any future protocol-based path is a deliberate change.
    @Test
    func `Encodable Double goes through JSON literal grammar`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("d", 3.14)
            }
        }
        #expect(url.absoluteString.contains("d=3.14"))
    }

    /// `Decimal` renders as a plain scalar through its base-10 `description`.
    ///
    /// It takes the `URLQueryValueConvertible` path rather than the generic JSON
    /// encoder. Foundation normalizes a `Decimal`'s trailing zeros at
    /// construction (even from an explicit scale), so `10.50` is already `10.5`
    /// before it ever reaches the query layer.
    @Test
    func `Decimal renders as a plain scalar via description`() throws {
        let amount = try #require(Decimal(string: "10.50"))
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("amount", amount)
            }
        }
        #expect(url.absoluteString == "https://example.com?amount=10.5")
    }

    /// A high-precision `Decimal` renders every significant digit.
    ///
    /// `description` preserves the full base-10 value, where a binary `Double`
    /// round-trip would round `0.1234567890123456789` to `0.12345678901234568`.
    @Test
    func `Decimal preserves precision beyond Double via description`() throws {
        let precise = try #require(Decimal(string: "0.1234567890123456789"))
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("amount", precise)
            }
        }
        #expect(url.absoluteString == "https://example.com?amount=0.1234567890123456789")
    }

    @Test
    func `Encodable String renders unquoted`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("s", "hello")
            }
        }
        #expect(url.absoluteString == "https://example.com?s=hello")
    }

    @Test
    func `supports explicit host declarations inside the host builder`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .subdomain("api")
                        .domain("apple")
                        .topLevelDomain(.dev)
                }
                Path {
                    "v1"
                    "status"
                }
            }
        }

        #expect(url.absoluteString == "https://api.apple.dev/v1/status")
    }

    @Test
    func `treats host labels without a TLD as a full validated host`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    "api"
                    "apple"
                    "com"
                }
            }
        }

        #expect(url.absoluteString == "https://api.apple.com")
    }

    /// RFC 3986 §3.2.2 — host is a single component; declaring the same
    /// component twice is structurally invalid.
    @Test
    func `rejects mixing a raw host with host builder labels`() {
        #expect(throws: URLBuildError.conflictingHostDeclarations) {
            try withThrowingURL {
                HTTPS {
                    Host("api.apple.com")
                    Host {
                        "www"
                        "apple"
                        TLD.com
                    }
                }
            }
        }
    }

    /// DSL shorthand — `tld(...)` is an alias for `topLevelDomain(...)` and
    /// produces an identical URL across direct component and host-builder
    /// call sites.
    @Test
    func `tld shorthand is equivalent to topLevelDomain`() throws {
        let viaDirectComponentLong = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
            }
        }
        let viaDirectComponentShort = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
            }
        }
        let viaComponentLong = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
            }
        }
        let viaComponentShort = try withThrowingURL {
            HTTPS {
                Domain("apple")
                TLD.com
            }
        }
        let viaHostShort = try withThrowingURL {
            HTTPS {
                Host {
                    .domain("apple")
                        .tld(.com)
                }
            }
        }
        let expected = "https://apple.com"
        #expect(viaDirectComponentLong.absoluteString == expected)
        #expect(viaDirectComponentShort.absoluteString == expected)
        #expect(viaComponentLong.absoluteString == expected)
        #expect(viaComponentShort.absoluteString == expected)
        #expect(viaHostShort.absoluteString == expected)
    }
}
