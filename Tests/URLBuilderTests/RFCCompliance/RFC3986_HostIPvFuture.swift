// =====================================================================
// RFC 3986 §3.2.2 — Host: IPvFuture
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc3986.txt §3.2.2
// Scope:   IPvFuture forward-compatibility grammar.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3986IPvFutureTests {
    // §3.2.2 ABNF:
    //   IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
    @Test
    func `§3.2.2 — accepts valid IPvFuture literal`() throws {
        let url = try withThrowingURL {
            HTTPS { IPLiteral("v1.a:b") }
        }
        #expect(url.absoluteString == "https://[v1.a:b]")
    }

    @Test(
        arguments: ["v.bad", "v1.", "vX.address"])
    func `§3.2.2 — rejects malformed IPvFuture literals`(literal: String) {
        #expect(throws: URLBuildError.invalidIPLiteral(literal)) {
            try withThrowingURL { HTTPS { IPLiteral(literal) } }
        }
    }
}
