import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct URLBuilderMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        URLMacro.self,
        URLQueryMacro.self,
        QueryAttributeMacro.self,
    ]
}
