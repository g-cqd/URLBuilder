// =====================================================================
// ResultBuilderControlFlowTests — exhaustive control-flow coverage
//
// Each `@URL…Builder` is exercised through `if`, `if let`, `if/else`,
// `for`, `switch`, and `guard` arms. This pins behaviour for the
// `buildOptional`, `buildEither(first:)`, `buildEither(second:)`, and
// `buildArray` arms across every builder.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("Result builders — control flow")
struct ResultBuilderControlFlowTests {
    // -----------------------------------------------------------------
    // @URLComponentBuilder — if/else, if let, for, switch
    // -----------------------------------------------------------------

    @Test
    func `@URLComponentBuilder supports if branches`() throws {
        let withWWW = true
        let url = try withThrowingURL {
            HTTPS {
                if withWWW { Subdomain("www") }
                Domain("apple")
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://www.apple.com")
    }

    @Test
    func `@URLComponentBuilder supports if/else branches`() throws {
        let useStaging = true
        let url = try withThrowingURL {
            HTTPS {
                if useStaging {
                    Subdomain("staging")
                } else {
                    Subdomain("api")
                }
                Domain("example")
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://staging.example.com")
    }

    @Test
    func `@URLComponentBuilder supports if let optional binding`() throws {
        let optionalSubdomain: String? = "api"
        let url = try withThrowingURL {
            HTTPS {
                if let label = optionalSubdomain { Subdomain(label) }
                Domain("example")
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://api.example.com")
    }

    @Test
    func `@URLComponentBuilder skips nil if let`() throws {
        let optionalSubdomain: String? = nil
        let url = try withThrowingURL {
            HTTPS {
                if let label = optionalSubdomain { Subdomain(label) }
                Domain("example")
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `@URLComponentBuilder supports for loops`() throws {
        let labels = ["api", "v2"]
        let url = try withThrowingURL {
            HTTPS {
                for label in labels { Subdomain(label) }
                Domain("example")
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://api.v2.example.com")
    }

    @Test
    func `@URLComponentBuilder supports switch branches`() throws {
        enum Environment { case dev, staging, prod }
        let env = Environment.staging

        let url = try withThrowingURL {
            HTTPS {
                switch env {
                    case .dev: Subdomain("dev")
                    case .staging: Subdomain("staging")
                    case .prod: Domain("example")
                }
                if env != .prod { Domain("example") }
                TLD.com
            }
        }
        #expect(url.absoluteString == "https://staging.example.com")
    }

    // -----------------------------------------------------------------
    // @URLPathBuilder — if/else, for, switch
    // -----------------------------------------------------------------

    @Test
    func `@URLPathBuilder supports if branches`() throws {
        let versioned = true
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path {
                    if versioned { "v1" }
                    "items"
                }
            }
        }
        #expect(url.absoluteString == "https://api.example.com/v1/items")
    }

    @Test
    func `@URLPathBuilder supports for loops`() throws {
        let parts = ["v1", "users", "42"]
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path {
                    for part in parts { part }
                }
            }
        }
        #expect(url.absoluteString == "https://api.example.com/v1/users/42")
    }

    @Test
    func `@URLPathBuilder supports if let optional binding`() throws {
        let suffix: String? = "search"
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path {
                    "v1"
                    if let suffix { suffix }
                }
            }
        }
        #expect(url.absoluteString == "https://api.example.com/v1/search")
    }

    @Test
    func `@URLPathBuilder supports switch branches`() throws {
        enum Resource { case items, users, posts }
        let resource = Resource.users

        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path {
                    "v1"
                    switch resource {
                        case .items: "items"
                        case .users: "users"
                        case .posts: "posts"
                    }
                }
            }
        }
        #expect(url.absoluteString == "https://api.example.com/v1/users")
    }

    // -----------------------------------------------------------------
    // @URLQueryBuilder — if, if let, for, switch (via URLQueryRepresentable)
    // -----------------------------------------------------------------

    struct ConditionalQueryDTO: URLQueryRepresentable {
        let q: String
        let strict: Bool
        let cursor: String?
        let tags: [String]

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", q)
            if strict { Query("strict", "1") }
            if let cursor { Query("cursor", cursor) }
            for tag in tags { Query("tag", tag) }
        }
    }

    @Test
    func `@URLQueryBuilder supports if/if let/for combined`() throws {
        let dto = ConditionalQueryDTO(
            q: "swift", strict: true, cursor: "abc", tags: ["ios", "concurrency"])
        let url = try withThrowingURL {
            HTTPS("api.example.com") { dto }
        }
        #expect(
            url.absoluteString
                == "https://api.example.com?q=swift&strict=1&cursor=abc&tag=ios&tag=concurrency"
        )
    }

    @Test
    func `@URLQueryBuilder skips false if and nil if let`() throws {
        let dto = ConditionalQueryDTO(q: "swift", strict: false, cursor: nil, tags: [])
        let url = try withThrowingURL {
            HTTPS("api.example.com") { dto }
        }
        #expect(url.absoluteString == "https://api.example.com?q=swift")
    }

    struct SwitchQueryDTO: URLQueryRepresentable {
        enum SortOrder { case ascending, descending }
        let order: SortOrder

        @URLQueryBuilder
        var urlQuery: [Query] {
            switch order {
                case .ascending: Query("sort", "asc")
                case .descending: Query("sort", "desc")
            }
        }
    }

    @Test
    func `@URLQueryBuilder supports switch branches`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                SwitchQueryDTO(order: .descending)
            }
        }
        #expect(url.absoluteString == "https://example.com?sort=desc")
    }

    // -----------------------------------------------------------------
    // @URLHostBuilder — if/else, for, switch
    // -----------------------------------------------------------------

    @Test
    func `@URLHostBuilder supports if branches`() throws {
        let withSubdomain = true
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    if withSubdomain { Host.subdomain("api") }
                    Host.domain("example")
                    Host.tld(.com)
                }
            }
        }
        #expect(url.absoluteString == "https://api.example.com")
    }

    @Test
    func `@URLHostBuilder supports for loops over subdomain labels`() throws {
        let subdomainLabels = ["api", "v2"]
        let url = try withThrowingURL {
            HTTPS {
                Host {
                    for label in subdomainLabels { Host.subdomain(label) }
                    Host.domain("example")
                    Host.tld(.com)
                }
            }
        }
        #expect(url.absoluteString == "https://api.v2.example.com")
    }

    @Test
    func `@URLHostBuilder supports switch branches`() throws {
        enum Region { case us, eu, asia }
        let region = Region.eu

        let url = try withThrowingURL {
            HTTPS {
                Host {
                    switch region {
                        case .us: Host.subdomain("us")
                        case .eu: Host.subdomain("eu")
                        case .asia: Host.subdomain("asia")
                    }
                    Host.domain("example")
                    Host.tld(.com)
                }
            }
        }
        #expect(url.absoluteString == "https://eu.example.com")
    }

    // -----------------------------------------------------------------
    // @URLRootBuilder — if/else (single declaration shape)
    // -----------------------------------------------------------------

    @Test
    func `@URLRootBuilder selects between schemes via if/else`() throws {
        let secure = true

        let url = try withThrowingURL {
            if secure {
                HTTPS("example.com")
            } else {
                HTTP("example.com")
            }
        }
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `@URLRootBuilder selects between schemes via switch`() throws {
        enum Protocol { case https, http }
        let proto = Protocol.http

        let url = try withThrowingURL {
            switch proto {
                case .https: HTTPS("example.com")
                case .http: HTTP("example.com")
            }
        }
        #expect(url.absoluteString == "http://example.com")
    }

    // -----------------------------------------------------------------
    // Boundary cases — empty, single-element, deeply nested
    // -----------------------------------------------------------------

    @Test
    func `empty if-arm in builder produces no component`() throws {
        let include = false
        let url = try withThrowingURL {
            HTTPS("example.com") {
                if include { Query("debug", "1") }
            }
        }
        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func `nested if inside for over queries`() throws {
        let labels = ["a", "b", "c"]
        let onlyEvenIndex = true
        struct LoopDTO: URLQueryRepresentable {
            let labels: [String]
            let onlyEvenIndex: Bool

            @URLQueryBuilder
            var urlQuery: [Query] {
                for (index, label) in labels.enumerated() where onlyEvenIndex && index % 2 == 0 {
                    Query("label", label)
                }
            }
        }

        let url = try withThrowingURL {
            HTTPS("example.com") {
                LoopDTO(labels: labels, onlyEvenIndex: onlyEvenIndex)
            }
        }
        #expect(url.absoluteString == "https://example.com?label=a&label=c")
    }

    @Test
    func `deeply nested control flow across multiple builders`() throws {
        let withVersion = true
        let resourceTypes = ["users", "posts"]
        let strict = true

        struct DTO: URLQueryRepresentable {
            let strict: Bool

            @URLQueryBuilder
            var urlQuery: [Query] {
                if strict { Query("strict") }
            }
        }

        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path {
                    if withVersion { "v1" }
                    for resource in resourceTypes { resource }
                }
                DTO(strict: strict)
            }
        }
        #expect(url.absoluteString == "https://api.example.com/v1/users/posts?strict")
    }

    // -----------------------------------------------------------------
    // guard return inside builder via early-return helper
    // -----------------------------------------------------------------

    @Test
    func `guard-style early exit via if produces an empty builder`() throws {
        func makeURL(includePath: Bool) throws -> URL {
            try withThrowingURL {
                HTTPS("example.com") {
                    if includePath {
                        Path {
                            "v1"
                            "items"
                        }
                    }
                }
            }
        }

        let withPath = try makeURL(includePath: true)
        let withoutPath = try makeURL(includePath: false)

        #expect(withPath.absoluteString == "https://example.com/v1/items")
        #expect(withoutPath.absoluteString == "https://example.com")
    }
}
