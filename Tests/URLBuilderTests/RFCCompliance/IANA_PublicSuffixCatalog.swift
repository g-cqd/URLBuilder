// =====================================================================
// IANA Root Zone + Mozilla PSL — Public Suffix Catalog
// ---------------------------------------------------------------------
// Source:  docs/References/TLDs/tlds-alpha-by-domain.txt
//          docs/References/TLDs/public_suffix_list.dat
//          docs/References/TLDs/icann-cctld-delegation-policy.html
// Scope:   Verifies the generated `PublicSuffix` catalog is loaded
//          correctly and exposes the expected single- and multi-label
//          suffixes. The catalog is regenerated automatically before
//          every build by the `PublicSuffixGeneratorPlugin` build tool
//          plugin from the vendored upstream files above.
//
// ISO/IEC scope note — ISO 3166-1 alpha-2 informs the country-code
// candidate set but does NOT govern URI structure. The IANA Root Zone
// Database is the operational authority for delegated ccTLDs; ICANN's
// ccTLD Delegation Policy makes ICANN's authority over the root zone
// independent of the ISO 3166 Maintenance Agency. These tests
// therefore validate the IANA + PSL catalog directly, not ISO 3166.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct IANAPublicSuffixCatalogTests {
    // Sanity: catalog is non-empty and contains common entries.
    @Test
    func `IANA — common gTLDs are present in icannTLDs`() {
        for tld in ["com", "org", "net", "edu", "gov", "fr", "de", "uk", "us", "io"] {
            #expect(PublicSuffix.icannTLDs.contains(tld), "missing \(tld)")
        }
    }

    // Mozilla PSL contains both single-label TLDs and multi-label
    // suffixes (e.g. co.uk, com.au, ac.uk).
    @Test(
        arguments: ["co.uk", "ac.uk", "gov.uk", "com.au", "co.jp", "com.br", "home.arpa"])
    func `Mozilla PSL — common multi-label suffixes are present in icannSuffixes`(suffix: String) {
        #expect(PublicSuffix.icannSuffixes.contains(suffix), "missing \(suffix)")
    }

    // longestMatch returns the longest-matching public suffix for a host.
    @Test(arguments: [
        ("example.co.uk", "co.uk" as String?),
        ("example.com", "com" as String?),
        ("router.home.arpa", "home.arpa" as String?),
        ("no-such-tld-zz", nil as String?)
    ])
    func `PublicSuffix.longestMatch — returns longest matching suffix`(
        host: String, expected: String?
    ) {
        let match = PublicSuffix.longestMatch(for: host)
        #expect(match == expected)
    }

    // `contains(_:)` is case-insensitive.
    @Test
    func `PublicSuffix.contains — case-insensitive`() {
        #expect(PublicSuffix.contains("COM"))
        #expect(PublicSuffix.contains("Co.Uk"))
    }

    @Test
    func `PublicSuffix.contains — applies PSL wildcard and exception semantics`() {
        #expect(PublicSuffix.icannWildcardParents.contains("kobe.jp"))
        #expect(PublicSuffix.icannExceptions.contains("city.kobe.jp"))
        #expect(PublicSuffix.contains("foo.kobe.jp"))
        #expect(PublicSuffix.contains("kobe.jp") == false)
        #expect(PublicSuffix.contains("city.kobe.jp") == false)
    }

    @Test
    func `PublicSuffix.longestMatch — exceptions prevail over wildcard rules`() {
        let wildcardMatch = PublicSuffix.longestMatch(for: "www.foo.kobe.jp")
        let exceptionMatch = PublicSuffix.longestMatch(for: "www.city.kobe.jp")
        #expect(wildcardMatch == "foo.kobe.jp")
        #expect(exceptionMatch == "kobe.jp")
    }

    // Generated single-label constants resolve and match raw-string form.
    @Test
    func `Generated TopLevelDomain constants match the literal string form`() {
        #expect(TopLevelDomain.com == TopLevelDomain("com"))
        #expect(TopLevelDomain.org == TopLevelDomain("org"))
    }

    @Test
    func `TopLevelDomain strips a leading dot from literal input`() {
        #expect(TopLevelDomain(".com").rawValue == "com")
    }
}

// =====================================================================
// @dynamicMemberLookup chain — TLD.co.uk, TLD.com.au, ...
// ---------------------------------------------------------------------
// Source: docs/References/TLDs/public_suffix_list.dat
// Scope:  Verifies that the dynamic-member chain composes labels
//         correctly, equals the raw-string form, hashes consistently,
//         and threads through every public DSL entry point that
//         accepts a `TopLevelDomain`.
// =====================================================================

struct TLDChainCompositionTests {
    // ----- Raw-value composition -----

    @Test(arguments: [
        ("co", "uk", "co.uk"),
        ("com", "au", "com.au"),
        ("ac", "uk", "ac.uk"),
        ("aichi", "nagoya", "aichi.nagoya")
    ])
    func `Two-label chain joins with '.'`(first: String, second: String, expected: String) {
        let chain = TopLevelDomain(first)[dynamicMember: second]
        #expect(chain.rawValue == expected)
    }

    @Test
    func `Chain extends an existing static TLD constant`() {
        #expect(TLD.co.uk.rawValue == "co.uk")
        #expect(TLD.com.au.rawValue == "com.au")
        #expect(TLD.ac.uk.rawValue == "ac.uk")
    }

    @Test
    func `Three-label chains compose left-to-right`() {
        // First hop must be a real static let; subsequent hops are
        // resolved through @dynamicMemberLookup. The result here is
        // intentionally not a real PSL entry — the test asserts that
        // composition works regardless of validity.
        let chain = TLD.com.example.demo
        #expect(chain.rawValue == "com.example.demo")
    }

    @Test
    func `Chain values are lowercased (matching TopLevelDomain init)`() {
        let chain = TopLevelDomain("CO")[dynamicMember: "UK"]
        #expect(chain.rawValue == "co.uk")
    }

    // ----- Equality and hashing -----

    @Test
    func `Chain value equals the literal-string form`() {
        #expect(TLD.co.uk == TopLevelDomain("co.uk"))
        #expect(TLD.com.au == TopLevelDomain("com.au"))
        #expect(TLD.ac.uk == TopLevelDomain("ac.uk"))
    }

    @Test
    func `Chain values hash consistently with literal-string form`() {
        let set: Set<TopLevelDomain> = [TLD.co.uk, TopLevelDomain("co.uk")]
        #expect(set.count == 1)
    }

    // ----- DSL integration: every entry point accepting a TLD -----

    @Test
    func `HTTPS(domain, TLD) accepts a chain value`() throws {
        let url = try withThrowingURL { HTTPS("bbc", TLD.co.uk) }
        #expect(url.absoluteString == "https://bbc.co.uk")
    }

    @Test
    func `HTTP(domain, TLD) accepts a chain value`() throws {
        let url = try withThrowingURL { HTTP("abc", TLD.com.au) }
        #expect(url.absoluteString == "http://abc.com.au")
    }

    @Test
    func `Host builder domain and tld accepts a chain value`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .domain("example")
                        .tld(TLD.co.jp)
                }
            }
        }
        #expect(url.absoluteString == "https://example.co.jp")
    }

    @Test
    func `Host result builder accepts a TLD chain value`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    "www"
                    "example"
                    TLD.co.uk
                }
            }
        }
        #expect(url.absoluteString == "https://www.example.co.uk")
    }

    @Test
    func `TopLevelDomain component accepts a chain value`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("example")
                TLD.com.br
            }
        }
        #expect(url.absoluteString == "https://example.com.br")
    }

    @Test
    func `TLD component accepts a chain value`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Domain("example")
                TLD.co.za
            }
        }
        #expect(url.absoluteString == "https://example.co.za")
    }

    // ----- Chains compose with subdomains -----

    @Test
    func `Chain composes with multiple subdomains`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    "api"
                    "v2"
                    "service"
                    TLD.co.uk
                }
            }
        }
        #expect(url.absoluteString == "https://api.v2.service.co.uk")
    }

    // ----- Sanity: chain output is in the PSL where expected -----

    @Test(arguments: [
        "co.uk", "com.au", "ac.uk", "co.jp", "com.br", "co.za"
    ])
    func `Common chain outputs are present in PublicSuffix.icannSuffixes`(suffix: String) {
        #expect(PublicSuffix.icannSuffixes.contains(suffix))
    }
}
