// =====================================================================
// DSL — Structural rules (cross-cutting RFC 3986 §3)
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §3 / §3.2
// Scope:   single-root URI, single-host component, port-requires-host.
//          These pin the DSL's structural invariants that mirror the
//          "URI = one syntactic unit" principle of RFC 3986 §3.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("DSL — Structural rules (cross-cutting RFC 3986 §3)")
struct DSLStructuralTests {
    // RFC 3986 §3 — A URI is one syntactic unit. The DSL enforces a
    // single root declaration per build call.
    @Test
    func `§3 — requires exactly one root URI declaration`() {
        #expect(throws: URLBuildError.missingRootURL) {
            try withThrowingURL {}
        }
        #expect(throws: URLBuildError.multipleRootURLs) {
            try withThrowingURL {
                HTTPS("one.example")
                HTTPS("two.example")
            }
        }
    }

    // RFC 3986 §3.2.2 — host is a single component; declaring it twice
    // is an error.
    @Test
    func `§3.2.2 — rejects conflicting full-host vs composed-host declarations`() {
        #expect(throws: URLBuildError.conflictingHostDeclarations) {
            try withThrowingURL {
                HTTPS {
                    Host("example.com")
                    Domain("apple")
                    TLD.com
                }
            }
        }
    }

    // RFC 3986 §3.2.3 — port appears only in the authority component.
    @Test
    func `§3.2 — rejects port without host (no authority)`() {
        #expect(throws: URLBuildError.portRequiresHost) {
            try withThrowingURL {
                URLDeclaration(scheme: Scheme("custom")) { Port(123) }
            }
        }
    }

    @Test
    func `§3.2.2 — rejects duplicate domain declarations`() {
        #expect(throws: URLBuildError.duplicateDomain) {
            try withThrowingURL {
                HTTPS {
                    Domain("example")
                    Domain("duplicate")
                    TLD.com
                }
            }
        }
    }

    @Test
    func `§3.2.2 — rejects duplicate TLD declarations`() {
        #expect(throws: URLBuildError.duplicateTopLevelDomain) {
            try withThrowingURL {
                HTTPS {
                    Domain("example")
                    TLD.com
                    TLD.org
                }
            }
        }
    }

    @Test
    func `§3.2.3 — rejects duplicate port declarations`() {
        #expect(throws: URLBuildError.duplicatePort) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Port(443)
                    Port(8443)
                }
            }
        }
    }

    @Test
    func `§3.5 — rejects duplicate fragment declarations`() {
        #expect(throws: URLBuildError.duplicateFragment) {
            try withThrowingURL {
                HTTPS("example.com") {
                    Fragment("one")
                    Fragment("two")
                }
            }
        }
    }
}
