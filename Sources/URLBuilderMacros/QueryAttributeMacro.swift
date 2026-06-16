import SwiftSyntax
import SwiftSyntaxMacros

/// `@Query` is a syntactic marker that `@URLQuery` reads during synthesis.
///
/// It configures a single property via `.key("…")`, `.flag`, or `.ignore` and
/// generates no peer declarations of its own.
struct QueryAttributeMacro: PeerMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        []
    }
}
