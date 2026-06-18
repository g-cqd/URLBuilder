// =====================================================================
// DomainNormalizerParityTests — generator/runtime single-source guard
//
// The public-suffix domain normalizer exists in two forms: the
// generator-side `PublicSuffixGenerator.normalizedDomain` (compiled into
// the dev tool) and the emitted `PublicSuffix.normalizedDomain` (generated
// into the shipped library). The emitted `String` helpers are single-sourced
// from `PublicSuffixGenerator.domainHelpersSource`; this suite locks the two
// normalizers to identical behavior over a shared fixture set so a future
// edit to one without the other is caught.
// =====================================================================

import Foundation
import Testing

@testable import PublicSuffixGeneratorCore
@testable import URLBuilder

@Suite("PublicSuffix — generator/runtime domain-normalizer parity")
struct DomainNormalizerParityTests {
    // Fixtures exercise accept and reject paths: case-folding, IDNA
    // (U-label → A-label), LDH boundaries, empty labels, and IP-like hosts.
    @Test(
        arguments: [
            "com", "COM", "co.uk", "Co.Uk", "example.com",
            "münchen.de", "café.fr", "xn--mnchen-3ya.de", "naïve.org",
            "192.168.1.1", "a-b.c-d.com",
            "co_uk", "ex ample.com", "-bad.com", "bad-.com",
            "", "a..b", "_dmarc.example.com"
        ])
    func `core and emitted normalizers agree on a fixture`(fixture: String) {
        #expect(
            PublicSuffixGenerator.normalizedDomain(fixture)
                == PublicSuffix.normalizedDomain(fixture)
        )
    }

    // Anchor a few concrete expectations so the parity check cannot pass by both
    // sides trivially returning `nil` for everything.
    @Test
    func `both normalizers perform IDNA and case-folding`() {
        #expect(PublicSuffix.normalizedDomain("MÜNCHEN.de") == "xn--mnchen-3ya.de")
        #expect(PublicSuffixGenerator.normalizedDomain("MÜNCHEN.de") == "xn--mnchen-3ya.de")
        #expect(PublicSuffix.normalizedDomain("Example.COM") == "example.com")
        #expect(PublicSuffixGenerator.normalizedDomain("Example.COM") == "example.com")
    }

    @Test
    func `both normalizers reject non-LDH input`() {
        #expect(PublicSuffix.normalizedDomain("co_uk") == nil)
        #expect(PublicSuffixGenerator.normalizedDomain("co_uk") == nil)
    }
}
