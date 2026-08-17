// =====================================================================
// RFC 5892 §2.2 / §2.3 — IDNA CONTEXTJ and CONTEXTO codepoints
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc5892.txt §2.2 + §2.3
//          docs/References/RFCs/rfc5891.txt §4.2.3.3
//          docs/References/ISO-IEC/DerivedCoreProperties.txt
// Scope:   ZERO WIDTH JOINER / NON-JOINER (§2.2) and the script-specific
//          §2.3 codepoints are PROTOCOL-VALID only when an explicit
//          contextual rule applies. Outside those contexts they MUST be
//          rejected. The DSL relies on Foundation's IDNA implementation
//          for these contextual checks; these tests pin the observable
//          outcome so a Foundation regression is caught at build time.
// =====================================================================

import AemiTestKit
import Foundation
import Testing
import URLBuilder

struct RFC5892ContextTests {
    // RFC 5892 §2.2 — CONTEXTJ codepoints:
    //   U+200C ZERO WIDTH NON-JOINER (ZWNJ)
    //   U+200D ZERO WIDTH JOINER     (ZWJ)
    // RFC 5891 §4.2.3.3 — they are valid only when the contextual rules
    // (Appendix A.1 / A.2) match. A bare ZWNJ between Latin letters has
    // no defined context and MUST be rejected.
    @Test
    func `§2.2 — rejects bare ZWNJ in Latin label (no contextual match)`() {
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{200C}bar", .com) }
        } where: { (error: URLBuildError) in
            // A bare CONTEXTJ codepoint with no contextual match is rejected as an invalid host.
            if case .invalidHost = error { true } else { false }
        }
    }

    @Test
    func `§2.2 — rejects bare ZWJ in Latin label (no contextual match)`() {
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{200D}bar", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.3 — CONTEXTO codepoints include:
    //   U+00B7 MIDDLE DOT (Catalan rule)
    //   U+0375 GREEK LOWER NUMERAL SIGN
    //   U+30FB KATAKANA MIDDLE DOT
    // These are valid only inside the script context the rule defines;
    // a Latin-only label containing them MUST be rejected.
    @Test(
        arguments: [
            "foo\u{00B7}bar",
            "foo\u{0375}bar",
            "foo\u{30FB}bar"
        ])
    func `§2.3 — rejects CONTEXTO codepoint outside its script context`(label: String) {
        expectThrows {
            try withThrowingURL { HTTPS(label, .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }
}
