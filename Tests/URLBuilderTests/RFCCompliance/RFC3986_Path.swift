// =====================================================================
// RFC 3986 §3.3 / §5.2.4 — Path and dot-segments
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.3 + §5.2.4
//          Documentation/References/RFCs/rfc9110.txt §4.2.3
// Scope:   path-segment grammar (pchar), traversal-segment rejection
//          (`.` / `..`), separator handling, empty-path rendering.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.3 / §5.2.4 — Path and dot-segments")
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
