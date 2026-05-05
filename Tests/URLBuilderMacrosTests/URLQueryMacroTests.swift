import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import URLBuilderMacros

@Suite("URLBuilderMacros — @URLQuery / @Query expansion")
struct URLQueryMacroTests {
    let macroSpecs: [String: MacroSpec] = [
        "URLQuery": MacroSpec(type: URLQueryMacro.self),
        "Query": MacroSpec(type: QueryAttributeMacro.self),
    ]

    @Test
    func `@URLQuery synthesizes scalar property as Query call`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
            }
            """,
            """
            struct Input {
              let q: String
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """
        )
    }

    @Test
    func `@URLQuery emits if-let for optional property`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let page: Int?
            }
            """,
            """
            struct Input {
              let page: Int?
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                if let page {
                    Query("page", page)
                }
              }
            }
            """
        )
    }

    @Test
    func `@URLQuery emits for-loop for array property`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let tags: [String]
            }
            """,
            """
            struct Input {
              let tags: [String]
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                for element in tags {
                    Query("tags", element)
                }
              }
            }
            """
        )
    }

    @Test
    func `@Query(.key) overrides the rendered key`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              @Query(.key("page_number")) let page: Int
            }
            """,
            """
            struct Input {
              let page: Int
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("page_number", page)
              }
            }
            """
        )
    }

    @Test
    func `@Query(.flag) renders Bool as flag with property name`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              @Query(.flag) let strict: Bool
            }
            """,
            """
            struct Input {
              let strict: Bool
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                if strict {
                    Query("strict")
                }
              }
            }
            """
        )
    }

    @Test
    func `@Query(.ignore) excludes a property from synthesis`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              @Query(.ignore) let trace: UUID
            }
            """,
            """
            struct Input {
              let q: String
              let trace: UUID
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """
        )
    }

    @Test
    func `@URLQuery composes scalar, optional, array, flag, ignore, custom key`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              @Query(.key("page_number")) let page: Int?
              let tags: [String]
              @Query(.flag) let strict: Bool
              @Query(.ignore) let trace: UUID
            }
            """,
            """
            struct Input {
              let q: String
              let page: Int?
              let tags: [String]
              let strict: Bool
              let trace: UUID
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
                if let page {
                    Query("page_number", page)
                }
                for element in tags {
                    Query("tags", element)
                }
                if strict {
                    Query("strict")
                }
              }
            }
            """
        )
    }

    @Test
    func `@URLQuery skips computed properties`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              var summary: String { q.uppercased() }
            }
            """,
            """
            struct Input {
              let q: String
              var summary: String { q.uppercased() }
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """
        )
    }

    private func expandsTo(
        _ source: String,
        _ expanded: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        assertMacroExpansion(
            source,
            expandedSource: expanded,
            macroSpecs: macroSpecs,
            failureHandler: { spec in
                Issue.record(
                    Comment(rawValue: spec.message),
                    sourceLocation: Testing.SourceLocation(
                        fileID: spec.location.fileID,
                        filePath: spec.location.filePath,
                        line: spec.location.line,
                        column: spec.location.column
                    )
                )
            }
        )
    }
}
