// =====================================================================
// RFC 3986 §3.2.2 — Host: reg-name (DNS)
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc3986.txt §3.2.2 + §6.2.2.1
//          docs/References/RFCs/rfc1035.txt  §2.3.1 / §2.3.4
// Scope:   DNS reg-name grammar, label length, label character set,
//          host case normalisation, trailing absolute-root dot.
// =====================================================================

import AemiTestKit
import Foundation
import Testing
import URLBuilder

struct RFC3986RegNameTests {
    // §3.2.2 — host case-insensitive, normalised to lowercase (§6.2.2.1).
    @Test
    func `§6.2.2.1 — lowercases mixed-case host`() throws {
        let url = try withThrowingURL { HTTPS("Example.COM") }
        #expect(url.host == "example.com")
    }

    // §3.2.2 — DNS labels MAY end with a trailing dot (absolute root).
    @Test
    func `§3.2.2 — preserves absolute DNS root dot`() throws {
        let url = try withThrowingURL { HTTPS("Example.COM.") }
        #expect(url.absoluteString == "https://example.com.")
    }

    // RFC 1035 §2.3.4 — DNS labels are 1-63 octets.
    @Test
    func `RFC 1035 §2.3.4 — rejects DNS label longer than 63 characters`() {
        let label = String(repeating: "a", count: 64)
        expectThrows {
            try withThrowingURL {
                HTTPS {
                    Host {
                        .domain(label)
                            .topLevelDomain(.com)
                    }
                }
            }
        } where: { (error: URLBuildError) in
            error == .invalidHostLabel(label)
        }
    }

    // §3.2.2 reg-name allowed characters (effectively IDNA after Foundation).
    @Test
    func `§3.2.2 — rejects DNS labels with invalid characters`() {
        #expect(throws: URLBuildError.invalidHostLabel("-apple")) {
            try withThrowingURL {
                HTTPS {
                    Host {
                        .domain("-apple")
                            .topLevelDomain(.com)
                    }
                }
            }
        }
    }
}
