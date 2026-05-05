import SwiftSyntax
import SwiftSyntaxMacros

/// `@Query(.key("…") | .flag | .ignore)` is a syntactic marker read by
/// `@URLQuery` during synthesis. It generates no peers itself.
public struct QueryAttributeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        []
    }
}
