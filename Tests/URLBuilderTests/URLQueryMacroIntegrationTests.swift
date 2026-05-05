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
}
