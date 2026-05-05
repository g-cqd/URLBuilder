// =====================================================================
// RFC 1035 / RFC 1123 — DNS Labels (LDH rule)
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc1035.txt §2.3.1 + §2.3.4
//          Documentation/References/RFCs/rfc1123.txt §2.1
//          Documentation/References/RFCs/rfc3986.txt §3.2.2 (reg-name)
// Scope:   DNS label preferred-syntax (LDH = Letter / Digit / Hyphen),
//          1-63 octet length, total host name 1-253 octets, hyphen
//          placement, RFC 1123 digit-leading allowance, trailing-dot
//          tolerance.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 1035 + RFC 1123 — DNS Labels (LDH)")
struct RFC1035DNSLabelsTests {

    // RFC 1035 §2.3.1 (preferred name syntax):
    //   <label> ::= <letter> [ [ <ldh-str> ] <let-dig> ]
    //   <ldh-str> ::= <let-dig-hyp> | <let-dig-hyp> <ldh-str>
    // RFC 1123 §2.1 relaxed the rule to allow digit-leading labels (e.g.
    // "3com.com"). Both forms are accepted by the DSL.
    @Test
    func `RFC 1123 §2.1 — accepts digit-leading DNS label`() throws {
        let url = try withThrowingURL { HTTPS("3com", .com) }
        #expect(url.absoluteString == "https://3com.com")
    }

    // RFC 1035 §2.3.4 — labels are 1..63 octets.
    @Test
    func `RFC 1035 §2.3.4 — accepts 63-octet maximum-length label`() throws {
        let label = String(repeating: "a", count: 63)
        let url = try withThrowingURL { HTTPS(label, .com) }
        #expect(url.host == "\(label).com")
    }

    @Test
    func `RFC 1035 §2.3.4 — rejects 64-octet over-limit label`() {
        let label = String(repeating: "a", count: 64)
        #expect(throws: (any Error).self) {
            try withThrowingURL { HTTPS(label, .com) }
        }
    }

    // RFC 1035 §2.3.4 — total length of an FQDN MUST NOT exceed 255 octets
    // including the implicit root dot, so the textual form is at most 253.
    // RFC 3986 §3.2.2 piggy-backs the same limit through `validatedHostName`.
    @Test
    func `RFC 1035 §2.3.4 — rejects host longer than 253 octets`() {
        let labels = (0..<5).map { _ in String(repeating: "a", count: 50) }
        let big = labels.joined(separator: ".") + ".com"
        #expect(big.utf8.count > 253)
        #expect(throws: (any Error).self) {
            try withThrowingURL { HTTPS(big) }
        }
    }

    @Test
    func `RFC 1035 §2.3.4 — accepts host at exact 253-octet limit`() throws {
        let labels = [
            String(repeating: "a", count: 63),
            String(repeating: "b", count: 63),
            String(repeating: "c", count: 63),
            String(repeating: "d", count: 61),
        ]
        let host = labels.joined(separator: ".")
        #expect(host.utf8.count == 253)

        let url = try withThrowingURL { HTTPS(host) }
        #expect(url.host(percentEncoded: false) == host)
    }

    // RFC 1035 §2.3.1 — labels MUST begin and end with a letter or digit.
    @Test(
        arguments: ["-leading", "trailing-"])
    func `RFC 1035 §2.3.1 — rejects labels starting or ending with a hyphen`(label: String) {
        #expect(throws: URLBuildError.invalidHostLabel(label)) {
            try withThrowingURL { HTTPS(label, .com) }
        }
    }

    // RFC 1035 §2.3.1 — interior hyphens are allowed.
    @Test
    func `RFC 1035 §2.3.1 — accepts interior hyphens in DNS label`() throws {
        let url = try withThrowingURL { HTTPS("a-b-c", .com) }
        #expect(url.absoluteString == "https://a-b-c.com")
    }

    @Test
    func `RFC 1035 §2.3.1 — rejects single-character composed TLD`() {
        #expect(throws: URLBuildError.invalidTopLevelDomain("a")) {
            try withThrowingURL {
                HTTPS("example", .custom("a"))
            }
        }
    }

    // RFC 3986 §3.2.2 — DNS host MAY end with a single trailing dot
    // representing the absolute (root) zone.
    @Test
    func `RFC 3986 §3.2.2 — preserves single trailing dot (absolute root)`() throws {
        let url = try withThrowingURL { HTTPS("Example.COM.") }
        #expect(url.absoluteString == "https://example.com.")
    }
}
