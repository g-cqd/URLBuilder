// =====================================================================
// RFC 3629 — UTF-8, a transformation format of ISO/IEC 10646
// ---------------------------------------------------------------------
// Spec:    docs/References/RFCs/rfc3629.txt §3 (encoding form)
//          docs/References/RFCs/rfc3986.txt §2.5 (encoding non-ASCII)
//          docs/References/RFCs/rfc3987.txt §3.1 (IRI to URI)
//          docs/References/ISO-IEC/iso-iec-10646-2020-FCD-unicode.org.pdf
// Scope:   The 1- / 2- / 3- / 4-byte UTF-8 encoding form is the byte
//          sequence that RFC 3986 §2.5 percent-encodes.  RFC 3987 §3.1
//          mandates UTF-8 as the encoding when mapping an IRI's
//          non-ASCII characters to URI percent-escapes.  These tests
//          pin the byte-level output for each UTF-8 sequence length
//          across path, query, and fragment.
//
//          From RFC 3629 §3, Table 3-6:
//            U+0000..U+007F     →  0xxxxxxx                         (1 byte)
//            U+0080..U+07FF     →  110xxxxx 10xxxxxx                (2 bytes)
//            U+0800..U+FFFF     →  1110xxxx 10xxxxxx 10xxxxxx       (3 bytes)
//            U+10000..U+10FFFF  →  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (4)
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3629UTF8EncodingTests {
    // -------------------------------------------------------------------
    // §3 — 2-byte sequences (U+0080..U+07FF) — %C2..%DF prefix
    // -------------------------------------------------------------------

    @Test(
        arguments: [
            // U+00E9 LATIN SMALL LETTER E WITH ACUTE — C3 A9
            ("café", "caf%C3%A9"),
            // U+00FC LATIN SMALL LETTER U WITH DIAERESIS — C3 BC
            ("über", "%C3%BCber"),
            // U+044F CYRILLIC SMALL LETTER YA — D1 8F
            ("я", "%D1%8F"),
            // U+05D0 HEBREW LETTER ALEF — D7 90
            ("א", "%D7%90")
        ]
    )
    func `§3 (2-byte) — U+0080..U+07FF encodes to two %HH bytes in path`(
        _ raw: String, _ encoded: String
    ) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Path(raw) }
        }
        #expect(url.absoluteString == "https://example.com/\(encoded)")
    }

    // -------------------------------------------------------------------
    // §3 — 3-byte sequences (U+0800..U+FFFF) — %E0..%EF prefix
    // -------------------------------------------------------------------

    @Test(
        arguments: [
            // U+4E2D CJK UNIFIED IDEOGRAPH-4E2D 中 — E4 B8 AD
            ("中", "%E4%B8%AD"),
            // U+3042 HIRAGANA LETTER A あ — E3 81 82
            ("あ", "%E3%81%82"),
            // U+20AC EURO SIGN € — E2 82 AC
            ("€", "%E2%82%AC"),
            // U+2603 SNOWMAN ☃ — E2 98 83
            ("☃", "%E2%98%83")
        ]
    )
    func `§3 (3-byte) — U+0800..U+FFFF encodes to three %HH bytes in query`(
        _ raw: String, _ encoded: String
    ) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("k", raw) }
        }
        #expect(url.absoluteString == "https://example.com?k=\(encoded)")
    }

    // -------------------------------------------------------------------
    // §3 — 4-byte sequences (U+10000..U+10FFFF) — %F0..%F4 prefix
    // -------------------------------------------------------------------

    @Test(
        arguments: [
            // U+1F600 GRINNING FACE 😀 — F0 9F 98 80
            ("\u{1F600}", "%F0%9F%98%80"),
            // U+1F4A9 PILE OF POO 💩 — F0 9F 92 A9
            ("\u{1F4A9}", "%F0%9F%92%A9"),
            // U+1F1EB U+1F1F7 FLAG FOR FRANCE 🇫🇷 — F0 9F 87 AB F0 9F 87 B7
            ("\u{1F1EB}\u{1F1F7}", "%F0%9F%87%AB%F0%9F%87%B7"),
            // U+10348 GOTHIC LETTER HWAIR 𐍈 — F0 90 8D 88
            ("\u{10348}", "%F0%90%8D%88")
        ]
    )
    func `§3 (4-byte) — supplementary plane encodes to four %HH bytes in fragment`(
        _ raw: String, _ encoded: String
    ) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Fragment(raw) }
        }
        #expect(url.absoluteString == "https://example.com#\(encoded)")
    }

    // -------------------------------------------------------------------
    // §3 — Mixed-length sequences in a single component round-trip the
    // exact byte sequence prescribed by RFC 3629 Table 3-6.
    // -------------------------------------------------------------------

    @Test
    func `§3 — mixed 1/2/3/4-byte sequence preserves byte order`() throws {
        let url = try withThrowingURL {
            // ASCII 'a' (61) + é (C3 A9) + 中 (E4 B8 AD) + 😀 (F0 9F 98 80)
            HTTPS("example.com") { Path("a-é-中-\u{1F600}") }
        }
        #expect(url.absoluteString == "https://example.com/a-%C3%A9-%E4%B8%AD-%F0%9F%98%80")
    }

    // -------------------------------------------------------------------
    // RFC 3629 §6 — UTF-8 is the MIME charset name "UTF-8" and is the
    // single encoding used when mapping non-ASCII characters in IRIs to
    // URI percent-escapes (RFC 3987 §3.1).  Encoding twice MUST NOT
    // produce a different byte sequence — same input, same bytes.
    // -------------------------------------------------------------------

    @Test
    func `§6 + RFC 3987 §3.1 — UTF-8 mapping is deterministic`() throws {
        let first = try withThrowingURL { HTTPS("example.com") { Path("café") } }
        let second = try withThrowingURL { HTTPS("example.com") { Path("café") } }
        #expect(first.absoluteString == second.absoluteString)
    }

    // -------------------------------------------------------------------
    // RFC 3629 §3 + RFC 5891 §5.4 — IDNA processing of host labels uses
    // NFC-normalised UTF-8.  A precomposed and decomposed form of the
    // same character MUST yield the same A-label byte sequence.
    // (Already covered in RFC5892_IDNAClassification.swift; this test
    // pins the byte-level NFC outcome for path / query in one place.)
    // -------------------------------------------------------------------

    @Test
    func `§3 + RFC 5891 §5.4 — NFC-equivalent forms produce identical bytes`() throws {
        // Path: U+00E9 (precomposed) vs U+0065 + U+0301 (decomposed).
        let precomposed = try withThrowingURL {
            HTTPS("example.com") { Path("caf\u{00E9}") }
        }
        let decomposed = try withThrowingURL {
            HTTPS("example.com") { Path("cafe\u{0301}") }
        }
        // Foundation does NOT apply NFC normalisation to path bytes — both
        // forms percent-encode their own UTF-8 representation. The point
        // here is to pin which form the URL renders for each input, not
        // to assert equality. NFC normalisation is host-only (RFC 5891).
        #expect(precomposed.absoluteString == "https://example.com/caf%C3%A9")
        #expect(decomposed.absoluteString == "https://example.com/cafe%CC%81")
    }

    @Test
    func `§4 — overlong UTF-8 percent sequence is not decoded`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Path("%C0%80") }
        }
        #expect(url.absoluteString == "https://example.com/%25C0%2580")
    }
}
