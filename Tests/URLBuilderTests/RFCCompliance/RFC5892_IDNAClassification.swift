// =====================================================================
// RFC 5892 — IDNA2008 codepoint classification
//             (backed by Unicode / ISO/IEC 10646)
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc5892.txt
//          docs/References/ISO-IEC/iso-iec-10646-2020-FCD-unicode.org.pdf
//          docs/References/ISO-IEC/UnicodeData.txt
//          docs/References/ISO-IEC/DerivedCoreProperties.txt
//
// RFC 5892 §1 derives every codepoint's IDNA category from properties
// defined by the Unicode Standard, which shares its repertoire with
// ISO/IEC 10646. The categories are:
//
//   §2.1 PVALID       — letters and digits permitted in U-labels
//   §2.2 CONTEXTJ     — ZWJ / ZWNJ; allowed only in defined contexts
//   §2.3 CONTEXTO     — script-specific (Greek / Hebrew / Katakana …)
//   §2.4 DISALLOWED   — surrogates, non-characters, controls, symbols,
//                       punctuation
//   §2.5 UNASSIGNED   — codepoint not yet assigned in ISO/IEC 10646
//
// These tests pin Foundation's IDNA behaviour for representative
// codepoints from each category so a future Foundation regression or
// platform divergence is caught at build time.
// =====================================================================

import ADTestKit
import Foundation
import Testing
import URLBuilder

struct RFC5892CodepointClassificationTests {
    // RFC 5892 §2.1 PVALID — LDH (letter / digit / hyphen) and Unicode
    // letters classified PVALID by the derived property table. ASCII
    // letters and digits round-trip without Punycode (no `xn--` prefix).
    @Test
    func `§2.1 PVALID — ASCII letters and digits accepted unchanged`() throws {
        let url = try withThrowingURL { HTTPS("abc123", .com) }
        #expect(url.absoluteString == "https://abc123.com")
    }

    // RFC 5892 §2.1 PVALID — ISO/IEC 10646 letters outside ASCII (e.g.
    // U+00E9 LATIN SMALL LETTER E WITH ACUTE) are PVALID and convert to
    // an A-label via Punycode (RFC 3492).
    @Test
    func `§2.1 PVALID — non-ASCII letter converts to Punycode A-label`() throws {
        let url = try withThrowingURL { HTTPS("café", .com) }
        #expect(url.absoluteString == "https://xn--caf-dma.com")
    }

    // RFC 5892 §2.4 DISALLOWED — symbols (Unicode general category Sm/Sc/Sk/So)
    // are DISALLOWED in U-labels. Emoji such as U+1F600 GRINNING FACE
    // (category So) MUST NOT appear in a host label. The DSL pre-checks
    // Unicode general category before handing the label to Foundation,
    // because Foundation's IDNA implementation Punycode-encodes emoji
    // instead of rejecting them.
    @Test
    func `§2.4 DISALLOWED — emoji symbol rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("hello\u{1F600}", .com) }
        } where: { (error: URLBuildError) in
            // DISALLOWED codepoint rejected by the pre-Foundation general-category check.
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.4 DISALLOWED — currency symbols (Sc) such as U+20AC EURO
    // SIGN are not letters and MUST be rejected.
    @Test
    func `§2.4 DISALLOWED — currency symbol rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("price\u{20AC}", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.4 DISALLOWED — math symbols (Sm) such as U+2260 NOT
    // EQUAL TO are not letters and MUST be rejected.
    @Test
    func `§2.4 DISALLOWED — math symbol rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("a\u{2260}b", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.4 DISALLOWED — punctuation (general category Pd/Pe/…/Po)
    // is DISALLOWED. U+2026 HORIZONTAL ELLIPSIS (Po) is not a letter and
    // must be rejected.
    @Test
    func `§2.4 DISALLOWED — punctuation/symbol rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{2026}bar", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.4 DISALLOWED — non-characters U+FDD0..U+FDEF and any
    // code point with the Unicode property `Noncharacter_Code_Point`
    // (UnicodeData/DerivedCoreProperties) are DISALLOWED. U+FFFE is the
    // canonical "byte-order mark sentinel" non-character.
    @Test
    func `§2.4 DISALLOWED — non-character codepoint rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{FFFE}bar", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5892 §2.4 DISALLOWED — C0 controls (U+0000..U+001F). U+0009
    // CHARACTER TABULATION is DISALLOWED. NUL is covered separately by
    // RFC 3986 §2 rejection.
    @Test
    func `§2.4 DISALLOWED — C0 control codepoint rejected in host label`() {
        expectThrows {
            try withThrowingURL { HTTPS("foo\u{0009}bar", .com) }
        } where: { (error: URLBuildError) in
            if case .invalidHost = error { true } else { false }
        }
    }

    // RFC 5891 §5.4 — Registration / lookup MUST apply Unicode
    // Normalization Form C (NFC) before classification. The DSL hands
    // the label to Foundation which performs IDNA processing including
    // NFC; an NFD-decomposed form must yield the same A-label as the
    // pre-composed form.
    @Test
    func `RFC 5891 §5.4 — NFC normalisation before IDNA processing`() throws {
        // U+00E9 (precomposed) vs U+0065 + U+0301 (decomposed).
        let precomposed = try withThrowingURL { HTTPS("caf\u{00E9}", .com) }
        let decomposed = try withThrowingURL { HTTPS("cafe\u{0301}", .com) }
        #expect(precomposed.absoluteString == decomposed.absoluteString)
        #expect(precomposed.absoluteString == "https://xn--caf-dma.com")
    }
}
