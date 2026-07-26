// =====================================================================
// RFC 3987 / RFC 5890–5894 — IRI and IDNA2008 (basics)
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc3987.txt §3.1
//          docs/References/RFCs/rfc5890.txt §2.3
//          docs/References/RFCs/rfc5891.txt §4
// Scope:   IRI-to-URI mapping, U-label / A-label conversion via Punycode,
//          A-label case normalisation, ucschar percent-encoding via UTF-8.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3987IRITests {
    // RFC 3987 §3.1 — Mapping IRI to URI
    // RFC 5890 §2.3 — U-label / A-label
    // RFC 5891 §4 — Lookup processing converts U-label to A-label
    // RFC 5892 — codepoint classification (backed by Unicode / ISO/IEC 10646)
    @Test
    func `RFC 3987 §3.1 + RFC 5891 §4 — U-label converted to A-label (Punycode)`() throws {
        let url = try withThrowingURL {
            HTTPS("exämple", .com)
        }
        #expect(url.absoluteString == "https://xn--exmple-cua.com")
    }

    // A-labels are case-insensitive; canonical form is lowercase.
    @Test
    func `RFC 5891 §4 — A-label case is normalised to lowercase`() throws {
        let url = try withThrowingURL { HTTPS("XN--EXMPLE-CUA.COM") }
        #expect(url.absoluteString == "https://xn--exmple-cua.com")
    }

    // RFC 3987 §3.1 — ucschar (non-ASCII) preserved in path segments via
    // percent-encoded UTF-8 bytes after URI mapping.
    @Test
    func `RFC 3987 §3.1 — non-ASCII path segment is percent-encoded via UTF-8`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Path("café") }
        }
        // "é" is U+00E9, UTF-8 = C3 A9 → "%C3%A9"
        #expect(url.absoluteString == "https://example.com/caf%C3%A9")
    }

    @Test
    func `RFC 3987 §3.1 — non-ASCII query value is percent-encoded via UTF-8`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("q", "café") }
        }
        #expect(url.absoluteString == "https://example.com?q=caf%C3%A9")
    }

    @Test(arguments: [
        "\u{200E}",
        "\u{200F}",
        "\u{202A}",
        "\u{202B}",
        "\u{202C}",
        "\u{202D}",
        "\u{202E}",
        "\u{2028}",
        "\u{2029}"
    ])
    func `RFC 3987 §4.1 — rejects bidi formatting characters in path/query/fragment`(scalar: String) {
        #expect(throws: URLBuildError.invalidPathSegment("safe\(scalar)path")) {
            try withThrowingURL {
                HTTPS("example.com") { Path("safe\(scalar)path") }
            }
        }

        #expect(throws: URLBuildError.invalidQueryName("safe\(scalar)name")) {
            try withThrowingURL {
                HTTPS("example.com") { Query("safe\(scalar)name", "value") }
            }
        }

        #expect(throws: URLBuildError.invalidQueryValue(name: "name", value: "safe\(scalar)value")) {
            try withThrowingURL {
                HTTPS("example.com") { Query("name", "safe\(scalar)value") }
            }
        }

        #expect(throws: URLBuildError.invalidFragment("safe\(scalar)fragment")) {
            try withThrowingURL {
                HTTPS("example.com") { Fragment("safe\(scalar)fragment") }
            }
        }
    }
}
