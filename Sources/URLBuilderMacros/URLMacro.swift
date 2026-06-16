import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#URL { ... }` — expands to `URLBuilder { ... }`.
struct URLMacro: ExpressionMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        let arguments = node.arguments
        let trailing = node.trailingClosure
        let additional = node.additionalTrailingClosures

        var output = "URLBuilder"
        if !arguments.isEmpty || trailing == nil {
            output += "(\(arguments.description))"
        }
        if let trailing {
            output += " \(trailing.description)"
        }
        for closure in additional {
            output += " \(closure.description)"
        }
        return "\(raw: output)"
    }
}
