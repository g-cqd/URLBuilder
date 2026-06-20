// =====================================================================
// URLQueryRepresentableTests — protocol-based query construction
//
// `URLQueryRepresentable` lets DTOs participate in the DSL without
// `Encodable`. Conforming types produce `[Query]` via `@URLQueryBuilder`
// — control flow (`if`, `for`, `switch`) is supported as in any other
// builder. `URLQueryValueConvertible` provides scalar conversion for the
// right-hand side without going through JSON.
// =====================================================================

import Foundation
import Testing
import URLBuilder

struct URLQueryRepresentableTests {
    // -----------------------------------------------------------------
    // Standard scalar conformances
    // -----------------------------------------------------------------

    @Test
    func `String renders verbatim through URLQueryValueConvertible`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("q", "hello") }
        }
        #expect(url.absoluteString == "https://example.com?q=hello")
    }

    @Test
    func `Int renders as decimal literal`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("page", 42) }
        }
        #expect(url.absoluteString == "https://example.com?page=42")
    }

    @Test(arguments: [(true, "true"), (false, "false")])
    func `Bool renders as true or false`(value: Bool, expected: String) throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("flag", value) }
        }
        #expect(url.absoluteString == "https://example.com?flag=\(expected)")
    }

    @Test
    func `Double renders without JSON quoting`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("d", 3.14) }
        }
        #expect(url.absoluteString.contains("d=3.14"))
    }

    @Test
    func `UUID renders as canonical UUID string`() throws {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("id", id) }
        }
        #expect(url.absoluteString.contains("id=11111111-2222-3333-4444-555555555555"))
    }

    @Test
    func `Date renders as ISO 8601 with fractional seconds`() throws {
        let date = Date(timeIntervalSince1970: 0)
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("when", date) }
        }
        // ISO 8601 fractional-seconds form starts with the date and contains "T".
        #expect(url.absoluteString.contains("when=1970-01-01T00:00:00.000"))
    }

    @Test
    func `Substring conforms to URLQueryValueConvertible`() throws {
        let full = "hello world"
        let firstWord = full.split(separator: " ").first!
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("greeting", firstWord) }
        }
        #expect(url.absoluteString == "https://example.com?greeting=hello")
    }

    @Test
    func `All integer widths conform to URLQueryValueConvertible`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("i8", Int8(-1))
                Query("u8", UInt8(255))
                Query("i32", Int32(123))
                Query("u64", UInt64(456))
            }
        }
        #expect(url.absoluteString == "https://example.com?i8=-1&u8=255&i32=123&u64=456")
    }

    // -----------------------------------------------------------------
    // RawRepresentable default conformance
    // -----------------------------------------------------------------

    enum RawSortDirection: String, URLQueryValueConvertible {
        case ascending = "asc"
        case descending = "desc"
    }

    @Test
    func `RawRepresentable enum conforms via default urlQueryValue`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("sort", RawSortDirection.descending) }
        }
        #expect(url.absoluteString == "https://example.com?sort=desc")
    }

    enum IntStatus: Int, URLQueryValueConvertible {
        case active = 1
        case archived = 2
    }

    @Test
    func `RawRepresentable with Int raw value renders as decimal`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") { Query("status", IntStatus.archived) }
        }
        #expect(url.absoluteString == "https://example.com?status=2")
    }

    // -----------------------------------------------------------------
    // URLQueryRepresentable DTO — basic
    // -----------------------------------------------------------------

    struct ScalarDTO: URLQueryRepresentable {
        let q: String
        let page: Int

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", q)
            Query("page", page)
        }
    }

    @Test
    func `scalar DTO expands inside HTTPS via buildExpression`() throws {
        let dto = ScalarDTO(q: "swift", page: 2)
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Path { "search" }
                dto
            }
        }
        #expect(url.absoluteString == "https://api.example.com/search?q=swift&page=2")
    }

    // -----------------------------------------------------------------
    // Optional property — if let pattern in builder
    // -----------------------------------------------------------------

    struct OptionalDTO: URLQueryRepresentable {
        let q: String
        let page: Int?

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", q)
            if let page { Query("page", page) }
        }
    }

    @Test
    func `optional property is omitted when nil via if let`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalDTO(q: "swift", page: nil)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift")
    }

    @Test
    func `optional property is included when present`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                OptionalDTO(q: "swift", page: 3)
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&page=3")
    }

    // -----------------------------------------------------------------
    // Array property — for loop emits one item per element
    // -----------------------------------------------------------------

    struct ArrayDTO: URLQueryRepresentable {
        let tags: [String]

        @URLQueryBuilder
        var urlQuery: [Query] {
            for tag in tags { Query("tag", tag) }
        }
    }

    @Test
    func `array property emits one query item per element under one key`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                ArrayDTO(tags: ["ios", "swift", "concurrency"])
            }
        }
        #expect(url.absoluteString == "https://example.com?tag=ios&tag=swift&tag=concurrency")
    }

    @Test
    func `empty array property produces no query`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                ArrayDTO(tags: [])
            }
        }
        #expect(url.absoluteString == "https://example.com")
    }

    // -----------------------------------------------------------------
    // Empty DTO produces no '?'
    // -----------------------------------------------------------------

    struct EmptyDTO: URLQueryRepresentable {
        @URLQueryBuilder
        var urlQuery: [Query] {}
    }

    @Test
    func `empty DTO produces no query separator in the URL`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Path { "items" }
                EmptyDTO()
            }
        }
        #expect(url.absoluteString == "https://example.com/items")
    }

    // -----------------------------------------------------------------
    // Nested DTO — composing URLQueryRepresentable values
    // -----------------------------------------------------------------

    struct PaginationDTO: URLQueryRepresentable {
        let page: Int
        let pageSize: Int

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("page", page)
            Query("page_size", pageSize)
        }
    }

    struct CompositeDTO: URLQueryRepresentable {
        let q: String
        let pagination: PaginationDTO

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", q)
            pagination
        }
    }

    @Test
    func `nested DTO flattens into siblings`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                CompositeDTO(q: "swift", pagination: PaginationDTO(page: 2, pageSize: 25))
            }
        }
        #expect(url.absoluteString == "https://example.com?q=swift&page=2&page_size=25")
    }

    // -----------------------------------------------------------------
    // Conditional / loop / switch in DTO body
    // -----------------------------------------------------------------

    enum SortKey: String, URLQueryValueConvertible {
        case name, createdAt, score
    }

    struct ControlFlowDTO: URLQueryRepresentable {
        let q: String
        let strict: Bool
        let sortKeys: [SortKey]
        let optionalCursor: String?

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", q)
            if strict { Query("strict") }
            for key in sortKeys {
                Query("sort", key)
            }
            if let optionalCursor { Query("cursor", optionalCursor) }
        }
    }

    @Test
    func `DTO supports if/for/optional binding inside @URLQueryBuilder body`() throws {
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                ControlFlowDTO(
                    q: "swift",
                    strict: true,
                    sortKeys: [.name, .score],
                    optionalCursor: "abc"
                )
            }
        }
        #expect(
            url.absoluteString
                == "https://api.example.com?q=swift&strict&sort=name&sort=score&cursor=abc"
        )
    }

    @Test
    func `DTO control flow drops absent branches`() throws {
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                ControlFlowDTO(q: "swift", strict: false, sortKeys: [], optionalCursor: nil)
            }
        }
        #expect(url.absoluteString == "https://api.example.com?q=swift")
    }

    // -----------------------------------------------------------------
    // Mixing DTO with sibling Query calls
    // -----------------------------------------------------------------

    @Test
    func `DTO composes with sibling Query declarations`() throws {
        let url = try withThrowingURL {
            HTTPS("api.example.com") {
                Query("api_key", "k123")
                ScalarDTO(q: "swift", page: 1)
                Query("trace", "off")
            }
        }
        #expect(
            url.absoluteString == "https://api.example.com?api_key=k123&q=swift&page=1&trace=off")
    }

    // -----------------------------------------------------------------
    // Interaction with QueryDeduplication
    // -----------------------------------------------------------------

    struct DuplicateKeyDTO: URLQueryRepresentable {
        let qFirst: String
        let qLast: String

        @URLQueryBuilder
        var urlQuery: [Query] {
            Query("q", qFirst)
            Query("q", qLast)
        }
    }

    @Test
    func `DTO duplicates collapse under .lastWins at first position`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.lastWins)) {
            HTTPS("example.com") {
                DuplicateKeyDTO(qFirst: "first", qLast: "last")
            }
        }
        #expect(url.absoluteString == "https://example.com?q=last")
    }

    @Test
    func `DTO duplicates collapse under .firstWins at first position`() throws {
        let url = try withThrowingURL(configuration: .default.queryDeduplication(.firstWins)) {
            HTTPS("example.com") {
                DuplicateKeyDTO(qFirst: "first", qLast: "last")
            }
        }
        #expect(url.absoluteString == "https://example.com?q=first")
    }

    // -----------------------------------------------------------------
    // Convenience init exists alongside URLQueryValue overload
    // -----------------------------------------------------------------

    @Test
    func `Query URLQueryValue overload still works for explicit values`() throws {
        let url = try withThrowingURL {
            HTTPS("example.com") {
                Query("preview", .empty)
                Query("flag", .flag)
            }
        }
        #expect(url.absoluteString == "https://example.com?preview=&flag")
    }
}
