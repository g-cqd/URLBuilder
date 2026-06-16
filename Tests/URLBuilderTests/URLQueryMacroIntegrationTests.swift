// =====================================================================
// URLQueryMacroIntegrationTests — runtime parity for @URLQuery / @Query
//
// These tests exercise the full macro pipeline: a DTO is annotated with
// `@URLQuery` (and per-property `@Query` peers), then participates in
// `URLBuilder { … }` end-to-end. The expanded conformance must produce
// query items identical to the hand-written equivalent.
// =====================================================================

import Foundation
import Testing
import URLBuilder

@Suite("URLBuilder — @URLQuery integration")
struct URLQueryMacroIntegrationTests {
    // -----------------------------------------------------------------
    // Scalar-only DTO
    // -----------------------------------------------------------------

    @URLQuery
    struct ScalarDTO {
        let q: String
        let page: Int
    }

    @Test
    func `@URLQuery scalar DTO matches hand-written URLQueryRepresentable`() throws {
        let dto = ScalarDTO(q: "swift", page: 2)
        let viaMacro = try withThrowingURL {
            HTTPS("api.example.com") {
                Path { "search" }
                dto
            }
        }
        #expect(viaMacro.absoluteString == "https://api.example.com/search?q=swift&page=2")
    }

    // -----------------------------------------------------------------
    // Optional + Array properties
    // -----------------------------------------------------------------

    @URLQuery
    struct OptionalArrayDTO {
        let q: String
        let page: Int?
        let tags: [String]
    }

    @Test
    func `@URLQuery optional property is omitted when nil`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalArrayDTO(q: "swift", page: nil, tags: [])
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    @Test
    func `@URLQuery optional + array unfold to expected items`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalArrayDTO(q: "swift", page: 2, tags: ["ios", "concurrency"])
            }
        }
        #expect(
            url.absoluteString == "https://example.com?q=swift&page=2&tags=ios&tags=concurrency"
        )
    }

    // -----------------------------------------------------------------
    // @Query(.key) override
    // -----------------------------------------------------------------

    @URLQuery
    struct CustomKeyDTO {
        let q: String
        @Query(.key("page_number")) let page: Int
    }

    @Test
    func `@Query(.key) renders the override at runtime`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                CustomKeyDTO(q: "swift", page: 3)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&page_number=3")
    }

    // -----------------------------------------------------------------
    // @Query(.flag) Bool rendering
    // -----------------------------------------------------------------

    @URLQuery
    struct FlagDTO {
        let q: String
        @Query(.flag) let strict: Bool
    }

    @Test
    func `@Query(.flag) renders true Bool as a flag`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                FlagDTO(q: "swift", strict: true)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&strict")
    }

    @Test
    func `@Query(.flag) omits false Bool from rendering`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                FlagDTO(q: "swift", strict: false)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    // -----------------------------------------------------------------
    // @Query(.ignore)
    // -----------------------------------------------------------------

    @URLQuery
    struct IgnoreDTO {
        let q: String
        @Query(.ignore) let trace: UUID
    }

    @Test
    func `@Query(.ignore) excludes the property at runtime`() throws {
        let trace = UUID()
        let url = try withThrowingURL {
            HTTPS("example.com") {
                IgnoreDTO(q: "swift", trace: trace)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    // -----------------------------------------------------------------
    // Mixed shapes — full coverage in one DTO
    // -----------------------------------------------------------------

    @URLQuery
    struct MixedDTO {
        let q: String
        @Query(.key("page_number")) let page: Int?
        let tags: [String]
        @Query(.flag) let strict: Bool
        @Query(.ignore) let trace: UUID
    }

    @Test
    func `@URLQuery composes all features at runtime`() throws {
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                MixedDTO(
                    q: "swift",
                    page: 2,
                    tags: ["ios", "concurrency"],
                    strict: true,
                    trace: UUID()
                )
            }
        }
        #expect(
            url.absoluteString
                == "https://api.example.com?q=swift&page_number=2&tags=ios&tags=concurrency&strict"
        )
    }

    // -----------------------------------------------------------------
    // Macro DTO composes with QueryDeduplication
    // -----------------------------------------------------------------

    @URLQuery
    struct AliasDTO {
        @Query(.key("q")) let qFirst: String
        @Query(.key("q")) let qLast: String
    }

    @Test
    func `@URLQuery DTO with two like-keys collapses under .lastWins`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                AliasDTO(qFirst: "first", qLast: "last")
            }
        }
        #expect(url.absoluteString == "https://example.com?q=last")
    }

    // -----------------------------------------------------------------
    // Empty DTO produces no query
    // -----------------------------------------------------------------

    @URLQuery
    struct EmptyDTO {
    }

    @Test
    func `@URLQuery empty DTO produces no query separator`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path { "items" }
                EmptyDTO()
            }
        }
        #expect(url.absoluteString == "https://example.com/items")
    }

    // -----------------------------------------------------------------
    // Optional collection unfolds (regression: an optional-of-array must
    // unfold to repeated keys, not collapse to a single JSON array value)
    // -----------------------------------------------------------------

    @URLQuery
    struct OptionalArrayUnfoldDTO {
        let q: String
        let tags: [String]?
    }

    @Test
    func `@URLQuery optional array unfolds to repeated keys when present`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalArrayUnfoldDTO(q: "swift", tags: ["ios", "spm"])
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&tags=ios&tags=spm")
    }

    @Test
    func `@URLQuery optional array is omitted entirely when nil`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalArrayUnfoldDTO(q: "swift", tags: nil)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    // -----------------------------------------------------------------
    // Set renders in a deterministic (sorted) order so URLs are stable
    // (HMAC signing, cache keys, snapshot tests)
    // -----------------------------------------------------------------

    @URLQuery
    struct SetDTO {
        let ids: Set<Int>
    }

    @Test
    func `@URLQuery Set renders in a deterministic sorted order`() throws {
        // The set is built so its native iteration order is unspecified; the
        // macro sorts it, so the rendered URL is identical on every run.
        let url = try withThrowingURL {
            HTTPS("example.com") {
                SetDTO(ids: Set([3, 1, 2]))
            }
        }
        #expect(url.absoluteString == "https://example.com?ids=1&ids=2&ids=3")
    }

    @URLQuery
    struct OptionalSetDTO {
        let tags: Set<String>?
    }

    @Test
    func `@URLQuery optional Set unfolds in sorted order when present`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalSetDTO(tags: Set(["b", "a", "c"]))
            }
        }
        #expect(url.absoluteString == "https://example.com?tags=a&tags=b&tags=c")
    }

    // -----------------------------------------------------------------
    // A custom key with quotes/backslashes must be escaped correctly in the
    // expansion — this DTO would not compile if the macro mis-escaped the key
    // -----------------------------------------------------------------

    @URLQuery
    struct SpecialKeyDTO {
        @Query(.key("a\"b\\c")) let value: String
    }

    @Test
    func `@Query(.key) with quotes and backslash round-trips the name`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                SpecialKeyDTO(value: "v")
            }
        }
        let names = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name)
        #expect(names == ["a\"b\\c"])
    }

    // -----------------------------------------------------------------
    // M1 — a `static` member is type-level state and must not leak into
    // any instance's query.
    // -----------------------------------------------------------------

    @URLQuery
    struct StaticMemberDTO {
        static let apiVersion = "v1"
        let q: String
    }

    @Test
    func `@URLQuery excludes static members at runtime`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                StaticMemberDTO(q: "swift")
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    // -----------------------------------------------------------------
    // M6 — a stored property with a `didSet` observer is real storage and
    // must be rendered (not skipped as if computed).
    // -----------------------------------------------------------------

    @URLQuery
    struct ObserverDTO {
        let q: String
        var page: Int = 1 {
            didSet {}
        }
    }

    @Test
    func `@URLQuery renders a stored property that has an observer`() throws {
        var dto = ObserverDTO(q: "swift")
        dto.page = 4
        let url = try withThrowingURL {
            HTTPS("example.com") {
                dto
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&page=4")
    }

    // -----------------------------------------------------------------
    // M7 — every binding of a multi-binding declaration is rendered, with
    // the trailing annotation propagated to earlier bindings.
    // -----------------------------------------------------------------

    @URLQuery
    struct MultiBindingDTO {
        let a, b: Int
    }

    @Test
    func `@URLQuery renders every binding of a multi-binding declaration`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                MultiBindingDTO(a: 1, b: 2)
            }
        }
        #expect(url.absoluteString == "https://example.com?a=1&b=2")
    }

    // -----------------------------------------------------------------
    // M2 — a keyword-named property is backtick-escaped in the expansion,
    // so it both compiles and renders under its bare name.
    // -----------------------------------------------------------------

    @URLQuery
    struct KeywordNameDTO {
        let `default`: Int
    }

    @Test
    func `@URLQuery renders a keyword-named property under its bare name`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                KeywordNameDTO(default: 5)
            }
        }
        #expect(url.absoluteString == "https://example.com?default=5")
    }
}
