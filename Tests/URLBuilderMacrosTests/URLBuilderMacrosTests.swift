import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import URLBuilderMacros

struct URLBuilderMacrosTests {
    let macroSpecs: [String: MacroSpec] = [
        "URL": MacroSpec(type: URLMacro.self)
    ]

    @Test
    func `#URL forwards a trailing closure to URLBuilder`() {
        expandsTo(
            """
            let u = #URL {
              HTTPS("example.com")
            }
            """,
            """
            let u = URLBuilder {
              HTTPS("example.com")
            }
            """
        )
    }

    @Test
    func `#URL forwards a configuration argument and trailing closure`() {
        expandsTo(
            """
            let u = #URL(configuration: .strict) {
              HTTPS("example.com")
            }
            """,
            """
            let u = URLBuilder(configuration: .strict) {
              HTTPS("example.com")
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
