// =====================================================================
// RFC 3986 §3.3 / §5.2.4 — Path and dot-segments
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc3986.txt §3.3 + §5.2.4
//          docs/References/RFCs/rfc9110.txt §4.2.3
// Scope:   path-segment grammar (pchar), traversal-segment rejection
//          (`.` / `..`), separator handling, empty-path rendering.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3986PathTests {
    // §3.3 — segment = *pchar; pchar excludes "/"
    // §5.2.4 — Remove Dot Segments: "." and ".." MUST be removed during
    // resolution. The DSL rejects them at construction time so callers
    // notice the bug instead of silently producing an unintended URL.
    @Test(
        arguments: [".", "..", "a/b", #"folder\name"#, "bad\0segment"])
    func `§3.3 + §5.2.4 — rejects literal dot, dot-dot, slash, backslash, and NUL segments`(
        segment: String
    ) {
        #expect(throws: URLBuildError.invalidPathSegment(segment)) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Path(segment)
                }
            }
        }
    }

    @Test
    func `§3.3 — appends multiple segments with single slash separators`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("v1", "tickets", "123")
            }
        }
        #expect(url.absoluteString == "https://example.com/v1/tickets/123")
    }

    // §3.3 — empty path = ""; with authority Foundation accepts but does
    // not render a slash. The DSL preserves declaration intent: absent
    // path stays absent, `Path("")` renders as `/`. RFC 9110 §4.2.3
    // states empty path and "/" are equivalent for http(s).
    @Test
    func `§3.3 + RFC 9110 §4.2.3 — explicit empty path renders as '/'`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Path("") }
        }
        #expect(url.absoluteString == "https://example.com/")
    }
}

// =====================================================================
// BUG 3 — Foundation path-encoding trust boundary (golden tests)
// ---------------------------------------------------------------------
// `URLDeclarationState.resolvedPath` VALIDATES segments but does not
// percent-encode them; encoding is delegated to the
// `URLComponents.path` setter (see the TRUST BOUNDARY note at the
// `components.path = …` assignment in URLDeclaration.swift). These golden
// tests PIN that delegated behavior so a future Foundation change cannot
// silently alter the emitted URL — and, critically, prove no reserved
// gen-delim in a path segment leaks into `URL.query` / `URL.fragment`.
// Foundation's behavior was investigated empirically and found CORRECT
// and non-injectable, so the segments are NOT re-encoded by the library.
// =====================================================================

struct RFC3986PathFoundationEncodingTests {
    private func path(_ segment: String) throws -> URL {
        try withThrowingURL {
            HTTPS("example.com") { Path(segment) }
        }
    }

    // A `?` in a path segment is percent-encoded as `%3F` and does NOT open a
    // query component — `URL.query` stays nil (no query injection).
    @Test
    func `a question mark in a segment is encoded and never starts a query`() throws {
        let url = try path("seg?injected=1")
        #expect(url.absoluteString == "https://example.com/seg%3Finjected=1")
        #expect(url.query == nil)
    }

    // A `#` in a path segment is percent-encoded as `%23` and does NOT open a
    // fragment — `URL.fragment` stays nil (no fragment injection).
    @Test
    func `a hash in a segment is encoded and never starts a fragment`() throws {
        let url = try path("seg#frag")
        #expect(url.absoluteString == "https://example.com/seg%23frag")
        #expect(url.fragment == nil)
    }

    // A bare/invalid `%` (not a valid triplet) is encoded as `%25`, producing a
    // valid percent-encoded path rather than malformed output.
    @Test(arguments: [
        (segment: "a%b", absolute: "https://example.com/a%25b"),
        (segment: "a%zzb", absolute: "https://example.com/a%25zzb"),
        // An existing valid triplet's `%` is itself escaped (`%41` → `%2541`):
        // Foundation does not double-decode, so the literal segment is preserved.
        (segment: "a%41b", absolute: "https://example.com/a%2541b")
    ])
    func `percent signs in a segment are encoded to valid triplets`(
        segment: String,
        absolute: String
    ) throws {
        let url = try path(segment)
        #expect(url.absoluteString == absolute)
    }

    // SPACE → `%20`.
    @Test
    func `a space in a segment is encoded as percent-twenty`() throws {
        let url = try path("a b")
        #expect(url.absoluteString == "https://example.com/a%20b")
    }

    // A non-ASCII scalar is percent-encoded via UTF-8 bytes.
    @Test
    func `a unicode segment is percent-encoded via UTF-8`() throws {
        let url = try path("café")
        #expect(url.absoluteString == "https://example.com/caf%C3%A9")
    }

    // `;` is a sub-delim admitted by the pchar grammar and stays literal — this
    // pins that the library does not over-encode it.
    @Test
    func `a semicolon in a segment is preserved as pchar`() throws {
        let url = try path("a;b")
        #expect(url.absoluteString == "https://example.com/a;b")
    }

    // A segment mixing space + `?` + `#` encodes all three in place with no
    // component leakage.
    @Test
    func `a segment mixing space, question, and hash encodes all three in place`() throws {
        let url = try path("x y?z#w")
        #expect(url.absoluteString == "https://example.com/x%20y%3Fz%23w")
        #expect(url.query == nil)
        #expect(url.fragment == nil)
    }
}
