import SwiftDiagnostics
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import URLBuilderMacros

@Suite("URLBuilderMacros — @Query peer marker")
struct QueryAttributeMacroTests {
    let macroSpecs: [String: MacroSpec] = [
        "URLQuery": MacroSpec(type: URLQueryMacro.self),
        "Query": MacroSpec(type: QueryAttributeMacro.self)
    ]

    @Test
    func `@Query alone (without @URLQuery on the type) generates no peer`() {
        expandsTo(
            """
            struct Input {
              @Query(.flag) let strict: Bool
            }
            """,
            """
            struct Input {
              let strict: Bool
            }
            """
        )
    }

    @Test
    func `@URLQuery on an enum is rejected with a diagnostic`() {
        expandsTo(
            """
            @URLQuery
            enum Status {
              case active
            }
            """,
            """
            enum Status {
              case active
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@URLQuery can only be applied to a struct, class, or actor.",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ]
        )
    }

    @Test
    func `@Query with a malformed argument is rejected with a diagnostic`() {
        expandsTo(
            """
            @URLQuery
            struct Input {
              @Query(.unknown) let q: String
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
            """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "@Query expects one of `.key(\"…\")`, `.flag`, or `.ignore` as its argument.",
                    line: 3,
                    column: 3,
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
