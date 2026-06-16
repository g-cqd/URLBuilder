// =====================================================================
// PublicAliasTests — pins the public convenience aliases that the rest of
// the suite did not exercise. Each alias forwards to an already-tested
// primitive; these tests lock the spelling and its behavior so a rename or
// signature change is caught.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("URLBuilder — public convenience aliases")
struct PublicAliasTests {
    @Test
    func `PathSegment.component composes a path like segment`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path {
                    PathSegment.component("v1").component("items")
                }
            }
        }
        #expect(url.absoluteString == "https://example.com/v1/items")
    }

    @Test
    func `Host.name sets a complete host like Host(_:)`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .name("api.apple.com")
                }
            }
        }
        #expect(url.absoluteString == "https://api.apple.com")
    }

    @Test
    func `Host.labels infers domain and subdomains from unclassified labels`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .labels("www", "apple").tld(.com)
                }
            }
        }
        #expect(url.absoluteString == "https://www.apple.com")
    }

    @Test
    func `Host.ipvFuture sets an RFC 3986 IPvFuture literal`() throws {
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .ipvFuture("v7.host")
                }
            }
        }
        #expect(url.absoluteString == "https://[v7.host]")
    }

    @Test
    func `UserInfo.username equals the username-only initializer`() {
        #expect(UserInfo.username("alice") == UserInfo(username: "alice"))
        #expect(UserInfo.username("alice").password == nil)
    }

    @Test
    func `TopLevelDomain.custom builds a multi-label public suffix`() throws {
        #expect(TopLevelDomain.custom("co.uk") == TopLevelDomain("co.uk"))

        let url = try withThrowingURL {
            HTTPS {
                Host {
                    .domain("example").tld(.custom("co.uk"))
                }
            }
        }
        #expect(url.absoluteString == "https://example.co.uk")
    }

    @Test
    func `Scheme(stringLiteral:) builds a scheme from a string literal`() {
        let scheme: Scheme = "wss"
        #expect(scheme.rawValue == "wss")
        #expect(scheme == Scheme("wss"))
    }

    @Test
    func `Scheme is CustomStringConvertible (parity with TopLevelDomain)`() {
        #expect(Scheme.https.description == "https")
        #expect(String(describing: Scheme("custom")) == "custom")
        #expect("\(Scheme.http)" == "http")
        // Parity: both DSL value types describe as their raw value.
        #expect(TopLevelDomain.com.description == "com")
    }
}
