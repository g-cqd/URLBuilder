// =====================================================================
// URLBuildConfiguration — opt-in public-suffix enforcement
// ---------------------------------------------------------------------
// Source:  Documentation/References/TLDs/public_suffix_list.dat
//          Documentation/References/TLDs/tlds-alpha-by-domain.txt
// Scope:   Verifies the opt-in `URLBuildConfiguration.tldEnforcement`
//          mode rejects TLDs and host suffixes that are absent from
//          `PublicSuffix.contains(_:)`. Default permissive behaviour
//          (Requirements §10.3) MUST remain unchanged.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct PublicSuffixEnforcementTests {
    // -------------------------------------------------------------------
    // Permissive mode (default) — every existing call site keeps working.
    // -------------------------------------------------------------------

    @Test
    func `Default configuration accepts unknown TLDs in composed hosts`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("example")
                TLD.custom("zzz")
            }
        }
        #expect(url.absoluteString == "https://example.zzz")
    }

    @Test
    func `Default configuration accepts unknown TLDs in host strings`() throws {
        let url = try withThrowingURL { HTTPS("example.zzz") }
        #expect(url.absoluteString == "https://example.zzz")
    }

    // -------------------------------------------------------------------
    // Strict mode — composed `.tld(...)` values.
    // -------------------------------------------------------------------

    @Test
    func `Strict mode accepts known single-label TLDs`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("example", .com)
        }
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `Strict mode accepts known multi-label suffixes via the chain`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("bbc", TLD.co.uk)
        }
        #expect(url.absoluteString == "https://bbc.co.uk")
    }

    @Test
    func `Strict mode accepts wildcard-child public suffixes`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("example", .custom("foo.kobe.jp"))
        }
        #expect(url.absoluteString == "https://example.foo.kobe.jp")
    }

    @Test
    func `Strict mode rejects PSL exception suffixes`() {
        #expect(throws: URLBuildError.unknownTopLevelDomain("city.kobe.jp")) {
            try withThrowingURL(configuration: .strict) {
                HTTPS("example", .custom("city.kobe.jp"))
            }
        }
    }

    @Test
    func `Strict mode rejects unknown single-label TLDs`() {
        #expect(throws: URLBuildError.unknownTopLevelDomain("zzz")) {
            try withThrowingURL(configuration: .strict) {
                HTTPS {
                    Domain("example")
                    TLD.custom("zzz")
                }
            }
        }
    }

    @Test
    func `Strict mode rejects unknown multi-label suffix chains`() {
        #expect(throws: URLBuildError.unknownTopLevelDomain("foo.bar")) {
            try withThrowingURL(configuration: .strict) {
                HTTPS {
                    Domain("example")
                    TLD.foo.bar
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // Strict mode — full host strings.
    // -------------------------------------------------------------------

    @Test
    func `Strict mode accepts host strings ending in a known suffix`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("example.com")
        }
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `Strict mode rejects host strings whose last label is not a TLD`() {
        #expect(
            throws: URLBuildError.unknownPublicSuffix(
                host: "example.con", label: "con"
            )
        ) {
            try withThrowingURL(configuration: .strict) {
                HTTPS("example.con")
            }
        }
    }

    @Test
    func `Strict mode accepts host strings under wildcard public suffixes`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("www.foo.kobe.jp")
        }
        #expect(url.absoluteString == "https://www.foo.kobe.jp")
    }

    @Test
    func `Strict mode resolves exception host strings to the parent suffix`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("www.city.kobe.jp")
        }
        #expect(url.absoluteString == "https://www.city.kobe.jp")
        #expect(PublicSuffix.longestMatch(for: "www.city.kobe.jp") == "kobe.jp")
    }

    @Test
    func `Strict mode accepts IPv4 literal hosts (TLD enforcement is name-only)`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS("192.168.1.1")
        }
        #expect(url.absoluteString == "https://192.168.1.1")
    }

    @Test
    func `Strict mode accepts IPv6 literal hosts (TLD enforcement is name-only)`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS {
                IPv6("2001:db8::1")
            }
        }
        #expect(url.absoluteString == "https://[2001:db8::1]")
    }

    // -------------------------------------------------------------------
    // Strict mode — Host result-builder form (subdomains + domain + tld).
    // -------------------------------------------------------------------

    @Test
    func `Strict mode accepts Host builder DSL with a known TLD`() throws {
        let url = try withThrowingURL(configuration: .strict) {
            HTTPS {
                Host {
                    "www"
                    "example"
                    TLD.com
                }
            }
        }
        #expect(url.absoluteString == "https://www.example.com")
    }

    @Test
    func `Strict mode rejects Host builder DSL with an unknown TLD`() {
        #expect(throws: URLBuildError.unknownTopLevelDomain("zzz")) {
            try withThrowingURL(configuration: .strict) {
                HTTPS {
                    Host {
                        "www"
                        "example"
                        TLD.custom("zzz")
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------
    // URLBuilder (trapping form) accepts the configuration parameter.
    // -------------------------------------------------------------------

    @Test
    func `URLBuilder(configuration: .strict) trapping form succeeds for known TLD`() {
        let url = URLBuilder(configuration: .strict) {
            HTTPS("example", .com)
        }
        #expect(url.absoluteString == "https://example.com")
    }
}
