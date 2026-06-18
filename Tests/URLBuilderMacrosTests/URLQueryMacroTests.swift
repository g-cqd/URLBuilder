import SwiftDiagnostics
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import URLBuilderMacros

@Suite("URLBuilderMacros — @URLQuery / @Query expansion")
struct URLQueryMacroTests {
    let macroSpecs: [String: MacroSpec] = [
        "URLQuery": MacroSpec(type: URLQueryMacro.self),
        "Query": MacroSpec(type: QueryAttributeMacro.self)
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

    @Test
    func `@URLQuery unfolds an optional array to repeated keys`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let tags: [String]?
            }
            """,
            """
            struct Input {
              let tags: [String]?
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                if let tags {
                    for element in tags {
                        Query("tags", element)
                    }
                }
              }
            }
            """
        )
    }

    @Test
    func `@URLQuery sorts Set iteration for a deterministic URL`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let ids: Set<Int>
            }
            """,
            """
            struct Input {
              let ids: Set<Int>
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                for element in ids.sorted(by: { String(describing: $0) < String(describing: $1)
                    }) {
                    Query("ids", element)
                }
              }
            }
            """
        )
    }

    @Test
    func `@Query(.key) escapes special characters in the rendered key`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              @Query(.key("a\\"b")) let value: String
            }
            """,
            """
            struct Input {
              let value: String
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("a\\"b", value)
              }
            }
            """
        )
    }

    // M1 — a `static`/`class` member is type-level state and must not leak into
    // every instance's query.
    @Test
    func `@URLQuery skips static and class members`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              static let version = "1"
              let q: String
            }
            """,
            """
            struct Input {
              static let version = "1"
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

    // M6 — a stored property with a `didSet`/`willSet` observer is real storage
    // and must NOT be skipped as if it were computed.
    @Test
    func `@URLQuery keeps a stored property that has observers`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              var page: Int = 1 {
                didSet {}
              }
            }
            """,
            """
            struct Input {
              var page: Int = 1 {
                didSet {}
              }
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("page", page)
              }
            }
            """
        )
    }

    // M7 — every binding in a multi-binding declaration is emitted, with the
    // trailing annotation propagated to earlier bindings.
    @Test
    func `@URLQuery emits every binding of a multi-binding declaration`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let a, b: Int
            }
            """,
            """
            struct Input {
              let a, b: Int
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("a", a)
                Query("b", b)
              }
            }
            """
        )
    }

    // M2 — a keyword-named property's value reference is backtick-escaped so the
    // expansion compiles.
    @Test
    func `@URLQuery backticks a keyword-named property reference`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let `default`: Int
            }
            """,
            """
            struct Input {
              let `default`: Int
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("default", `default`)
              }
            }
            """
        )
    }

    // M3 — a dictionary property has no canonical query unfold and is diagnosed.
    @Test
    func `@URLQuery diagnoses a dictionary property`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              let headers: [String: Int]
            }
            """,
            """
            struct Input {
              let q: String
              let headers: [String: Int]
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@URLQuery does not support dictionary properties — a dictionary has no "
                        + "canonical query unfold. Encode it explicitly with a custom "
                        + "URLQueryRepresentable, or exclude it with @Query(.ignore).",
                    line: 4,
                    column: 16,
                    severity: .error
                )
            ]
        )
    }

    // M4 — an un-annotated collection literal would silently JSON-encode; require
    // an explicit annotation instead.
    @Test
    func `@URLQuery diagnoses an un-annotated collection literal`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              let tags = ["ios", "swift"]
            }
            """,
            """
            struct Input {
              let q: String
              let tags = ["ios", "swift"]
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@URLQuery needs an explicit type annotation on a collection property "
                        + "(e.g. `let tags: [String]`) so it can unfold to repeated query items "
                        + "instead of encoding the literal.",
                    line: 4,
                    column: 7,
                    severity: .error
                )
            ]
        )
    }

    // M5 — a nested optional is not `URLQueryValueConvertible` after one unwrap;
    // diagnose rather than emit a non-compiling binding.
    @Test
    func `@URLQuery diagnoses a nested optional property`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              let q: String
              let page: Int??
            }
            """,
            """
            struct Input {
              let q: String
              let page: Int??
            }

            extension Input: URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                Query("q", q)
              }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@URLQuery does not support nested optionals — flatten to a single "
                        + "optional, or exclude it with @Query(.ignore).",
                    line: 4,
                    column: 13,
                    severity: .error
                )
            ]
        )
    }

    private func expandsTo(
        _ source: String,
        _ expanded: String,
        diagnostics: [DiagnosticSpec] = [],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        assertMacroExpansion(
            source,
            expandedSource: expanded,
            diagnostics: diagnostics,
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
