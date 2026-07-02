// =====================================================================
// RFC 3492 — Punycode (Bootstring for IDNA)
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3492.txt
//          Documentation/References/RFCs/rfc5891.txt §4.4 (toASCII)
// Scope:   U-label → A-label conversion uses the Punycode (Bootstring)
//          algorithm. Each non-ASCII U-label MUST yield an A-label that
//          starts with the ACE prefix "xn--" (RFC 5891 §4.4 / RFC 5890
//          §2.3.2.1).
// =====================================================================

import Foundation
import Testing
import URLBuilder

// RFC 3492 §3 / RFC 5891 §4.4 — well-known Punycode encodings.
// German "bücher" → "xn--bcher-kva"; French "café" → "xn--caf-dma";
// Cyrillic "пример" → "xn--e1afmkfd". The A-label MUST start with
// the ACE prefix "xn--".
// Typed file-scope fixture: a concrete Sendable struct (not a tuple) keeps both the literal's
// inference and the @Test macro thunk's per-argument tuple machinery out of the
// (type-check-budgeted) test body.
struct ALabelFixture: Sendable, CustomStringConvertible {
    let input: String
    let expected: String
    var description: String { input }
}

private let knownALabelEncodings: [ALabelFixture] = [
    ALabelFixture(input: "bücher", expected: "xn--bcher-kva"),
    ALabelFixture(input: "café", expected: "xn--caf-dma"),
    ALabelFixture(input: "пример", expected: "xn--e1afmkfd"),
    ALabelFixture(input: "中国", expected: "xn--fiqs8s")
]

struct RFC3492PunycodeTests {
    /// Builds `https://<input>.com` and returns its host. Extracted so the DSL closure's
    /// overload resolution is type-checked once here, not inside the budgeted parameterized
    /// test body the @Test macro thunk re-checks.
    private func builtHost(for input: String) throws -> String? {
        let url = try withThrowingURL { HTTPS(input, .com) }
        return url.host
    }

    @Test(arguments: knownALabelEncodings)
    func `RFC 3492 — U-label round-trips through known A-label encoding`(
        fixture: ALabelFixture
    ) throws {
        let host: String? = try builtHost(for: fixture.input)
        let expectedHost: String? = fixture.expected + ".com"
        #expect(host == expectedHost)
    }

    // RFC 5891 §4.4 / RFC 5890 §2.3.2.1 — every expected A-label in the fixture set carries the
    // ACE prefix, so the exact-equality test above also pins the prefix requirement.
    @Test
    func `RFC 5890 §2.3.2.1 — every fixture A-label starts with the ACE prefix`() {
        let prefixed: Bool = knownALabelEncodings.allSatisfy { $0.expected.hasPrefix("xn--") }
        #expect(prefixed)
    }

    // RFC 5890 §2.3.2.1 — ACE prefix "xn--" is case-insensitive on input;
    // canonical output is lowercase.
    @Test
    func `RFC 5890 §2.3.2.1 — ACE prefix is case-insensitive on input`() throws {
        let url = try withThrowingURL { HTTPS("XN--CAF-DMA", .com) }
        #expect(url.host == "xn--caf-dma.com")
    }

    // RFC 3492 §6.1 — encodings round-trip: decoding the A-label back
    // yields the original U-label. We do not perform decoding here, but
    // we pin that the same input always maps to the same output, which
    // is sufficient for callers relying on stable URLs.
    @Test
    func `RFC 3492 — encoding is deterministic for the same input`() throws {
        let first = try withThrowingURL { HTTPS("café", .com) }
        let second = try withThrowingURL { HTTPS("café", .com) }
        #expect(first.absoluteString == second.absoluteString)
    }

    // RFC 5891 §4.5 — A-label MUST round-trip to the same Unicode label
    // it was derived from. Pre-encoded Punycode passed in MUST NOT be
    // double-encoded.
    @Test
    func `RFC 5891 §4.5 — pre-encoded A-label is not double-encoded`() throws {
        let url = try withThrowingURL { HTTPS("xn--caf-dma", .com) }
        #expect(url.host == "xn--caf-dma.com")
    }

    // RFC 5891 §4 — a COMPLETE Unicode host string (multi-label, passed through
    // the reg-name path) is accepted and converted to its A-label form. This
    // pins the deliberate reliance on the lenient `URL(string:)` re-parse in
    // `URLValidator.validatedHostName`: the stricter
    // `URL(string:encodingInvalidCharacters: false)` would DISABLE Foundation's
    // IDNA (U-label → A-label) conversion and reject every internationalized
    // domain. A future Foundation change at that boundary is caught here.
    @Test
    func `RFC 5891 — complete Unicode host is accepted and IDNA-encoded`() throws {
        let url = try withThrowingURL { HTTPS("münchen.de") }
        #expect(url.host == "xn--mnchen-3ya.de")
        #expect(url.absoluteString == "https://xn--mnchen-3ya.de")
    }
}
