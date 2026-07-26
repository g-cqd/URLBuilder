// =====================================================================
// RFC 5952 §5 — IPv6 with Embedded IPv4 (mixed text form)
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc5952.txt §5
//          docs/References/RFCs/rfc4291.txt §2.5.5 + §2.2 (3)
// Scope:   IPv4-mapped (::ffff:0:0/96) and IPv4-compatible (::/96)
//          forms.  RFC 5952 §5 RECOMMENDS the dotted-quad form ONLY
//          when the address belongs to one of the well-defined embedded
//          ranges; outside those ranges the pure-hex form is preferred.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC5952EmbeddedIPv4Tests {
    // RFC 4291 §2.5.5.2 — IPv4-mapped IPv6 addresses: ::ffff:a.b.c.d
    // RFC 5952 §5      — keep the dotted-quad form for these addresses.
    @Test
    func `RFC 5952 §5 — accepts IPv4-mapped IPv6 dotted-quad form`() throws {
        let url: URL = try withThrowingURL { HTTPS { IPv6("::ffff:192.0.2.1") } }
        #expect(url.absoluteString == "https://[::ffff:192.0.2.1]")
    }

    // RFC 4291 §2.5.5.1 — IPv4-compatible IPv6 (::a.b.c.d).  Deprecated
    // but still syntactically valid.
    @Test
    func `RFC 4291 §2.5.5.1 — accepts IPv4-compatible IPv6 dotted-quad form`() throws {
        let url: URL = try withThrowingURL { HTTPS { IPv6("::192.0.2.1") } }
        #expect(url.absoluteString == "https://[::192.0.2.1]")
    }

    // RFC 5952 §5 — embedded IPv4 octets must be in dotted-quad range.
    @Test
    func `RFC 5952 §5 — rejects embedded IPv4 with out-of-range octet`() {
        #expect(throws: URLBuildError.invalidIPv6Address("::ffff:300.0.0.1")) {
            try withThrowingURL { HTTPS { IPv6("::ffff:300.0.0.1") } }
        }
    }
}
