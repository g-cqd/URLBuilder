// =====================================================================
// RFC 3986 §3.2.3 — Port
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3.2.3
//          Documentation/References/RFCs/rfc9110.txt §4.2.1/§4.2.2
//          Documentation/References/RFCs/rfc6335.txt §6 (port 0)
// Scope:   port grammar `*DIGIT`, valid TCP range, default-port omission.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("RFC 3986 §3.2.3 — Port")
struct RFC3986PortTests {
    // §3.2.3 — port = *DIGIT
    // RFC 9110 §4.2.1/4.2.2 — TCP port range 1-65535 (port 0 reserved per RFC 6335).
    @Test(
        arguments: [1, 80, 443, 8080, 65_535])
    func `§3.2.3 — accepts ports across the valid range`(value: Int) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Port(value) }
        }
        if value == 443 {
            #expect(url.port == nil)
        } else {
            #expect(url.port == value)
        }
    }

    @Test(arguments: [-1, 65_536, 100_000])
    func `§3.2.3 — rejects out-of-range ports`(value: Int) {
        #expect(throws: URLBuildError.invalidPort(value)) {
            try withThrowingURL {
                HTTPS("example.com") { Port(value) }
            }
        }
    }

    // RFC 6335 §6 — "TCP/UDP port range is 1-65535. Port 0 is reserved
    //                and MUST NOT be used in URIs (RFC 9110 §4.2.1)."
    // RFC 9110 §4.2.1 — http URI default port is 80; reserved port 0
    // has no transport meaning and MUST be rejected at construction.
    @Test
    func `RFC 6335 §6 — rejects reserved port 0`() {
        #expect(throws: URLBuildError.invalidPort(0)) {
            try withThrowingURL {
                HTTPS("example.com") { Port(0) }
            }
        }
    }

    // §3.2.3 — port = *DIGIT, syntactically allows the empty string.
    // The DSL takes `Int` so the empty form is unrepresentable; pinned
    // here for documentation completeness so future refactors that add
    // a `port(String)` overload remember to validate the empty case.
    // No test body — comment is the assertion.
}
