// =====================================================================
// RFC 3986 §2 — Characters and Percent-Encoding
// ---------------------------------------------------------------------
// Spec:    Documentation/References/RFCs/rfc3986.txt §2
// Scope:   percent-encoding triplet syntax, reserved/unreserved sets,
//          double-encoding avoidance, hex case normalisation, and the
//          NUL byte rejection that keeps strings out of the
//          unreserved / reserved / pct-encoded grammar.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct RFC3986CharactersTests {
    // §2.1 Percent-Encoding
    // > A percent-encoded octet is encoded as a character triplet,
    // > consisting of the percent character "%" followed by the two
    // > hexadecimal digits representing that octet's numeric value.
    @Test
    func `§2.1 — percent-encodes space in path as %20`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("a b")
            }
        }
        #expect(url.absoluteString == "https://example.com/a%20b")
    }

    @Test
    func `§2.1 — percent-encodes space in query value as %20`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("k", "a b")
            }
        }
        #expect(url.absoluteString == "https://example.com?k=a%20b")
    }

    // §2.2 Reserved Characters
    // > URI producing applications should percent-encode data octets that
    // > correspond to characters in the reserved set unless these
    // > characters are specifically allowed by the URI scheme.
    // The path pchar set (§3.3) explicitly admits `:@!$&'()*+,;=` and `-._~`.
    @Test
    func `§2.2 — preserves pchar reserved/sub-delims and unreserved in path`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("colon:at@sub!$&'()*+,;=")
            }
        }
        #expect(url.absoluteString == "https://example.com/colon:at@sub!$&'()*+,;=")
    }

    // §2.3 Unreserved Characters
    // > unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    // > For consistency, percent-encoded octets in the ranges of ALPHA,
    // > DIGIT, hyphen, period, underscore, or tilde should not be created
    // > by URI producers.
    @Test
    func `§2.3 — passes the full unreserved set unencoded in path`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("ABCxyz0189-._~")
            }
        }
        #expect(url.absoluteString == "https://example.com/ABCxyz0189-._~")
    }

    // §2.4 When to Encode or Decode
    // > Implementations must not percent-encode or decode the same string
    // > more than once, as decoding an already decoded string might lead
    // > to misinterpreting a percent data octet as the beginning of a
    // > percent-encoding […].
    @Test
    func `§2.4 — does not double-encode an existing percent triplet in path`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("%20")
            }
        }
        let urlPath = url.path
        #expect(urlPath == "/%20")
    }

    // §6.2.2.2 Percent-Encoding Normalization
    // > For consistency, percent-encoded octets in the ranges of ALPHA
    // > […] uppercase hexadecimal digits.
    @Test
    func `§6.2.2.2 — percent-encoding uses uppercase hex digits`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path("a b")
                Query("k", "Ä")
            }
        }
        let s = url.absoluteString
        var i = s.startIndex
        while let pct = s.range(of: "%", range: i ..< s.endIndex) {
            let after = pct.upperBound
            guard s.distance(from: after, to: s.endIndex) >= 2 else { break }
            let hex = s[after ..< s.index(after, offsetBy: 2)]
            for ch in hex where ch.isLetter {
                #expect(ch.isUppercase, "expected uppercase hex; got \(ch) in \(s)")
            }
            i = s.index(after, offsetBy: 2)
        }
    }
}

// ---------------------------------------------------------------------
// §2 NUL byte rejection — NUL (U+0000) has no valid percent-encoded
// form in the URI grammar (it sits outside unreserved/reserved/
// pct-encoded). The DSL rejects it across every textual component.
// ---------------------------------------------------------------------

struct RFC3986NULRejectionTests {
    @Test
    func `§2 — rejects NUL in path segment`() {
        #expect(throws: URLBuildError.invalidPathSegment("bad\0segment")) {
            try withThrowingURL {
                HTTPS("example.com") { Path("bad\0segment") }
            }
        }
    }

    @Test
    func `§3.4 — rejects NUL in query name`() {
        #expect(throws: URLBuildError.invalidQueryName("bad\0name")) {
            try withThrowingURL {
                HTTPS("example.com") { Query("bad\0name", "value") }
            }
        }
    }

    @Test
    func `§3.4 — rejects NUL in query value`() {
        #expect(throws: URLBuildError.invalidQueryValue(name: "name", value: "bad\0value")) {
            try withThrowingURL {
                HTTPS("example.com") { Query("name", "bad\0value") }
            }
        }
    }

    @Test
    func `§3.5 — rejects NUL in fragment`() {
        #expect(throws: URLBuildError.invalidFragment("bad\0fragment")) {
            try withThrowingURL {
                HTTPS("example.com") { Fragment("bad\0fragment") }
            }
        }
    }
}
