// =====================================================================
// RFC 2606 / RFC 6761 / RFC 6762 / RFC 7686 / RFC 8375 / RFC 9476
//   — Special-Use Domain Names
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc2606.txt §2 + §3
//          Documentation/References/RFCs/rfc6761.txt §6
//          Documentation/References/RFCs/rfc6762.txt §3
//          Documentation/References/RFCs/rfc7686.txt §2
//          Documentation/References/RFCs/rfc8375.txt §3
//          Documentation/References/RFCs/rfc9476.txt §2
// Scope:   Reserved and special-use TLDs (.test / .example / .invalid /
//          .localhost / .local / .onion / .home.arpa / .alt). The DSL
//          accepts them as well-formed labels because the URI grammar
//          (RFC 3986 §3.2.2) does not require any TLD registry lookup;
//          callers who need stricter behaviour can consult the IANA
//          registry mirrored in `PublicSuffix.icannTLDs`.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 2606/6761/6762/7686/8375/9476 — Special-Use TLDs")
struct SpecialUseTLDTests {
    // RFC 2606 §2 — reserved TLDs intentionally never delegated by IANA.
    //   .test  .example  .invalid  .localhost
    // The DSL accepts them; rejection is policy, not URI grammar.
    @Test(
        arguments: [
            ("foo", TopLevelDomain("test"), "https://foo.test"),
            ("foo", TopLevelDomain("example"), "https://foo.example"),
            ("foo", TopLevelDomain("invalid"), "https://foo.invalid"),
            ("foo", TopLevelDomain("localhost"), "https://foo.localhost"),
        ])
    func `RFC 2606 §2 — accepts reserved TLDs as well-formed hosts`(
        domain: String, tld: TopLevelDomain, expected: String
    ) throws {
        let url = try withThrowingURL { HTTPS(domain, tld) }
        #expect(url.absoluteString == expected)
    }

    // RFC 6762 §3 — `.local` is reserved for multicast DNS (mDNS); valid
    // syntactic host name.
    @Test
    func `RFC 6762 §3 — accepts .local mDNS host as well-formed`() throws {
        let url = try withThrowingURL { HTTPS("printer", TopLevelDomain("local")) }
        #expect(url.absoluteString == "https://printer.local")
    }

    // RFC 7686 §2 — `.onion` is reserved for the Tor anonymous network.
    // It is a syntactically valid TLD; cryptographic v3 onion service
    // names use base32 56-character labels which exceed the 63-octet
    // DNS label limit.  The 16-character v2 form fits the LDH rule.
    @Test
    func `RFC 7686 §2 — accepts v2-style 16-char .onion host`() throws {
        let url = try withThrowingURL { HTTPS("3g2upl4pq6kufc4m", TopLevelDomain("onion")) }
        #expect(url.absoluteString == "https://3g2upl4pq6kufc4m.onion")
    }

    // RFC 8375 §3 — `.home.arpa` is the reserved suffix for residential
    // home-network names. Used as a multi-label public suffix.
    @Test
    func `RFC 8375 §3 — accepts .home.arpa multi-label suffix`() throws {
        let url = try withThrowingURL { HTTPS("router", TopLevelDomain("home.arpa")) }
        #expect(url.absoluteString == "https://router.home.arpa")
    }

    // RFC 9476 §2 — `.alt` is reserved for use as a non-DNS pseudo-TLD
    // for alternative naming systems.
    @Test
    func `RFC 9476 §2 — accepts .alt pseudo-TLD as well-formed host`() throws {
        let url = try withThrowingURL { HTTPS("foo", TopLevelDomain("alt")) }
        #expect(url.absoluteString == "https://foo.alt")
    }

    // The PSL ICANN catalog includes the reserved suffixes.  Pin that
    // `home.arpa` is recognised so callers can build an opt-in policy.
    @Test
    func `RFC 8375 — home.arpa is present in the ICANN PSL catalog`() {
        #expect(PublicSuffix.contains("home.arpa"))
    }
}
