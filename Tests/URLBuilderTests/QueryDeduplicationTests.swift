// =====================================================================
// QueryDeduplicationTests — opt-in render-time dedup policies
//
// RFC 3986 §3.4 and WHATWG URL Living Standard §5.1 both define the
// query as an ordered list of name-value pairs preserving duplicates.
// `.none` (default) matches that. `.lastWins` and `.firstWins` collapse
// duplicates while keeping the *first occurrence's position* in the
// rendered URL — matching `URLSearchParams.set` placement semantics
// (WHATWG URL §6.2).
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("URLBuildConfiguration — QueryDeduplication")
struct QueryDeduplicationTests {
    // -----------------------------------------------------------------
    // .none (default) — preserves order and duplicates
    // -----------------------------------------------------------------

    @Test
    func `.none preserves repeated keys in declaration order`() throws {
        let url = try withThrowingURL(configuration: .default) {
            HTTPS("api.example.com") {
                Path { "search" }
                Query("q", "swift")
                Query("page", 1)
                Query("q", "concurrency")
                Query("limit", 20)
                Query("q", "actors")
            }
        }

        #expect(
            url.absoluteString
                == "https://api.example.com/search?q=swift&page=1&q=concurrency&limit=20&q=actors")
    }

    @Test
    func `.none is the default policy`() {
        #expect(URLBuildConfiguration.default.queryDeduplication == .none)
    }

    // -----------------------------------------------------------------
    // .lastWins — last value wins, anchored at first-occurrence position
    // -----------------------------------------------------------------

    @Test
    func `.lastWins keeps the last value at the first occurrence's position`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("api.example.com") {
                Path { "search" }
                Query("q", "swift")
                Query("page", 1)
                Query("q", "concurrency")
                Query("limit", 20)
                Query("q", "actors")
            }
        }

        #expect(
            url.absoluteString == "https://api.example.com/search?q=actors&page=1&limit=20")
    }

    @Test
    func `.lastWins overrides interleaved keys at their first positions`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("api.example.com") {
                Path { "items" }
                Query("sort", "asc")
                Query("page", 1)
                Query("sort", "desc")
                Query("limit", 20)
                Query("page", 2)
            }
        }

        #expect(
            url.absoluteString == "https://api.example.com/items?sort=desc&page=2&limit=20")
    }

    // -----------------------------------------------------------------
    // .firstWins — first value wins, anchored at first-occurrence position
    // -----------------------------------------------------------------

    @Test
    func `.firstWins keeps the first value and drops later occurrences`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("api.example.com") {
                Path { "search" }
                Query("q", "swift")
                Query("page", 1)
                Query("q", "concurrency")
                Query("limit", 20)
                Query("q", "actors")
            }
        }

        #expect(
            url.absoluteString == "https://api.example.com/search?q=swift&page=1&limit=20")
    }

    @Test
    func `.firstWins preserves the first value across interleaved keys`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("api.example.com") {
                Path { "items" }
                Query("sort", "asc")
                Query("page", 1)
                Query("sort", "desc")
                Query("limit", 20)
                Query("page", 2)
            }
        }

        #expect(
            url.absoluteString == "https://api.example.com/items?sort=asc&page=1&limit=20")
    }

    // -----------------------------------------------------------------
    // Single-occurrence keys are untouched by any policy
    // -----------------------------------------------------------------

    @Test(
        arguments: [
            URLBuildConfiguration.QueryDeduplication.none,
            URLBuildConfiguration.QueryDeduplication.firstWins,
            URLBuildConfiguration.QueryDeduplication.lastWins
        ]
    )
    func `single-occurrence keys are unchanged across policies`(
        policy: URLBuildConfiguration.QueryDeduplication
    ) throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(policy)) {
            HTTPS("api.example.com") {
                Query("a", "1")
                Query("b", "2")
                Query("c", "3")
            }
        }

        #expect(url.absoluteString == "https://api.example.com?a=1&b=2&c=3")
    }

    // -----------------------------------------------------------------
    // Idempotency — running the policy twice yields the same output
    // -----------------------------------------------------------------

    @Test
    func `.lastWins is idempotent over the rendered URL`() throws {
        let firstPass = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                Query("k", "1")
                Query("k", "2")
                Query("k", "3")
            }
        }
        let secondPass = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                Query("k", "3")
            }
        }

        #expect(firstPass.absoluteString == secondPass.absoluteString)
    }

    @Test
    func `.firstWins is idempotent over the rendered URL`() throws {
        let firstPass = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("example.com") {
                Query("k", "1")
                Query("k", "2")
                Query("k", "3")
            }
        }
        let secondPass = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("example.com") {
                Query("k", "1")
            }
        }

        #expect(firstPass.absoluteString == secondPass.absoluteString)
    }

    // -----------------------------------------------------------------
    // Empty / single-key edge cases
    // -----------------------------------------------------------------

    @Test
    func `dedup policies leave a query-less URL unchanged`() throws {
        for policy in [
            URLBuildConfiguration.QueryDeduplication.none,
            .firstWins,
            .lastWins
        ] as [URLBuildConfiguration.QueryDeduplication] {
            let url = try withThrowingURL(configuration: .default.queryDeduplication(policy)) {
                HTTPS("example.com") {
                    Path { "items" }
                }
            }
            #expect(url.absoluteString == "https://example.com/items")
        }
    }

    @Test
    func `.lastWins on a single duplicate key collapses to one entry`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                Query("tag", "ios")
                Query("tag", "swift")
                Query("tag", "concurrency")
            }
        }
        #expect(url.absoluteString == "https://example.com?tag=concurrency")
    }

    @Test
    func `.firstWins on a single duplicate key collapses to one entry`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("example.com") {
                Query("tag", "ios")
                Query("tag", "swift")
                Query("tag", "concurrency")
            }
        }
        #expect(url.absoluteString == "https://example.com?tag=ios")
    }

    // -----------------------------------------------------------------
    // Flag and empty values participate in dedup the same as scalars
    // -----------------------------------------------------------------

    @Test
    func `.lastWins replaces a flag with a later value declaration`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                Query("preview")
                Query("preview", "v2")
            }
        }
        #expect(url.absoluteString == "https://example.com?preview=v2")
    }

    @Test
    func `.firstWins keeps a flag declared first`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("example.com") {
                Query("preview")
                Query("preview", "v2")
            }
        }
        #expect(url.absoluteString == "https://example.com?preview")
    }

    // -----------------------------------------------------------------
    // Interaction with .formURLEncoded encoding shape
    // -----------------------------------------------------------------

    @Test
    func `.lastWins composes with formURLEncoded query encoding`() throws {
        let configuration = URLBuildConfiguration(
            queryEncoding: .formURLEncoded,
            queryDeduplication: .lastWins
        )

        let url = try withThrowingURL(configuration: configuration) {
            HTTPS("example.com") {
                Query("q", "first value")
                Query("q", "final value")
            }
        }

        #expect(url.absoluteString == "https://example.com?q=final+value")
    }

    // -----------------------------------------------------------------
    // Modifier method round-trip
    // -----------------------------------------------------------------

    @Test
    func `queryDeduplication modifier returns a configuration with the requested policy`() {
        let configuration = URLBuildConfiguration.default.queryDeduplication(.lastWins)
        #expect(configuration.queryDeduplication == .lastWins)

        let toggled = configuration.queryDeduplication(.firstWins)
        #expect(toggled.queryDeduplication == .firstWins)
    }
}
