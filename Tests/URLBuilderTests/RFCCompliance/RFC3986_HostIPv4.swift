// =====================================================================
// RFC 3986 §3.2.2 — Host: IPv4address
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.2.2
// Scope:   dotted-quad IPv4 grammar; rejection of out-of-range and
//          zero-padded octets.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3986IPv4Tests {
    // §3.2.2 ABNF:
    //   IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
    //   dec-octet   = DIGIT / %x31-39 DIGIT / "1" 2DIGIT
    //              / "2" %x30-34 DIGIT / "25" %x30-35
    @Test
    func `§3.2.2 — accepts canonical IPv4 literals`() throws {
        let url = try withThrowingURL {
            HTTPS("127.0.0.1") { Port(8080) }
        }
        #expect(url.absoluteString == "https://127.0.0.1:8080")
    }

    // out-of-range octet → "256.0.0.1"
    // leading zero in octet → "127.000.000.001" (rejected by Foundation)
    @Test(
        arguments: ["256.0.0.1", "127.000.000.001"])
    func `§3.2.2 — rejects out-of-range and zero-padded IPv4 octets`(host: String) {
        #expect(throws: URLBuildError.invalidHost(host)) {
            try withThrowingURL { HTTPS(host) }
        }
    }
}
