// =====================================================================
// RFC 3986 §3.2.2 / RFC 4291 / RFC 5952 / RFC 9844 — Host: IPv6
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.2.2 (IP-literal)
//          Documentation/References/RFCs/rfc4291.txt §2.2 (text forms)
//          Documentation/References/RFCs/rfc5952.txt §4.1-§4.3 (canonical)
//          Documentation/References/RFCs/rfc9844.txt §4 (zone IDs)
// Scope:   IPv6 literal canonicalisation, bracketing, and rejection of
//          zone identifiers in URI host literals.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.2.2 / RFC 4291 / RFC 5952 — Host: IPv6address")
struct RFC4291_5952IPv6Tests {

    // RFC 4291 §2.2 — three text forms (full, compressed, mixed v4/v6).
    // RFC 5952 §4.1 — leading zeros suppressed.
    // RFC 5952 §4.2 — "::" used to compress longest run of zeros.
    // RFC 5952 §4.3 — lowercase hex.
    // RFC 3986 §3.2.2 — IP-literal = "[" IPv6address "]"
    @Test
    func `RFC 5952 §4.1+§4.2+§4.3 — canonicalizes leading zeros, lowercases, compresses`() throws {
        let url = try withThrowingURL {
            HTTPS {
                IPv6("2001:0DB8:0000:0000:0000:0000:0000:0001")
            }
        }
        #expect(url.absoluteString == "https://[2001:db8::1]")
    }

    // RFC 5952 §4.2.2 — "::" applied to longest run; if multiple runs of
    // equal length, applied to the leftmost.
    @Test
    func `RFC 5952 §4.2.2 — '::' compresses the longest zero run`() throws {
        let url = try withThrowingURL {
            HTTPS {
                IPv6("2001:db8:0:0:1:0:0:0")
            }
        }
        #expect(url.host(percentEncoded: false) == "2001:db8:0:0:1::")
    }

    // RFC 3986 §3.2.2 — IP-literal MUST be enclosed in brackets in URI form.
    @Test
    func `RFC 3986 §3.2.2 — accepts pre-bracketed IPv6 literal`() throws {
        let url = try withThrowingURL {
            HTTPS { IPv6("[::1]") }
        }
        #expect(url.absoluteString == "https://[::1]")
    }

    // RFC 4291 §2.2 (1) — Preferred form: x:x:x:x:x:x:x:x where each x is
    // one to four hexadecimal digits. The full 8-group form is the
    // canonical input shape; canonical OUTPUT is governed by RFC 5952.
    @Test(
        arguments: [
            ("2001:db8:0:0:0:0:0:1", "2001:db8::1"),
            ("fe80:0:0:0:0:0:0:1", "fe80::1"),
            ("0:0:0:0:0:0:0:1", "::1"),
        ]
    )
    func `RFC 4291 §2.2 (1) — accepts full 8-group preferred form`(
        literal: String, expectedHost: String
    ) throws {
        let url = try withThrowingURL { HTTPS { IPv6(literal) } }
        // Canonical form per RFC 5952 §4.1/§4.2 will lowercase + compress.
        #expect(url.host(percentEncoded: false) == expectedHost)
    }

    // RFC 4291 §2.2 (2) — Compressed form: "::" represents one or more
    // groups of 16 bits of zeros and may appear once. Already exercised
    // throughout this suite via short literals; pinned here explicitly.
    @Test(
        arguments: ["::", "::1", "1::", "fe80::1", "2001:db8::"]
    )
    func `RFC 4291 §2.2 (2) — accepts compressed form '::'`(literal: String) throws {
        let url = try withThrowingURL { HTTPS { IPv6(literal) } }
        #expect(url.host?.contains(":") == true)
    }

    // RFC 4291 §2.2 — only one "::" is allowed per address. The DSL
    // delegates parsing to Foundation; assert rejection of double-"::"
    // shapes that violate §2.2.
    @Test
    func `RFC 4291 §2.2 — rejects multiple '::' substitutions`() {
        #expect(throws: URLBuildError.invalidIPv6Address("1::2::3")) {
            try withThrowingURL { HTTPS { IPv6("1::2::3") } }
        }
    }

    // Negative cases: malformed brackets.
    @Test(
        arguments: ["[::1", "::1]", "[[::1]]", " ::1"])
    func `RFC 3986 §3.2.2 — rejects malformed bracket pairs`(literal: String) {
        #expect(throws: URLBuildError.invalidIPv6Address(literal)) {
            try withThrowingURL { HTTPS { IPv6(literal) } }
        }
    }
}

// ---------------------------------------------------------------------
// RFC 9844 §4 — Zone identifiers are UI-only; URI host literals MUST
// NOT contain a zone ID. Obsoletes the experimental syntax of RFC 6874.
// ---------------------------------------------------------------------

@Suite("RFC 9844 — IPv6 Zone Identifiers in URIs (obsoletes RFC 6874)")
struct RFC9844ZoneIdentifierTests {

    @Test
    func `RFC 9844 §4 — rejects IPv6 zone identifier in URI host literal`() {
        #expect(throws: URLBuildError.invalidIPv6Address("fe80::1%en0")) {
            try withThrowingURL {
                HTTPS { IPv6("fe80::1%en0") }
            }
        }
    }
}
