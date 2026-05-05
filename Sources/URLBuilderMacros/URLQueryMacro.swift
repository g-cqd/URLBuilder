import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@URLQuery` synthesizes `URLQueryRepresentable` conformance by reading
/// stored properties of a struct/class/actor.
///
/// Per-property configuration uses the peer macro `@Query`:
///   • `@Query(.key("custom_name"))` overrides the rendered key.
///   • `@Query(.flag)` renders a `Bool` property as a value-less flag.
///   • `@Query(.ignore)` excludes the property from the synthesis.
public struct URLQueryMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let memberBlock: MemberBlockSyntax
        if let s = declaration.as(StructDeclSyntax.self) {
            memberBlock = s.memberBlock
        } else if let c = declaration.as(ClassDeclSyntax.self) {
            memberBlock = c.memberBlock
        } else if let a = declaration.as(ActorDeclSyntax.self) {
            memberBlock = a.memberBlock
        } else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: URLQueryMacroDiagnostic.unsupportedDeclaration
                )
            )
            return []
        }

        let storedProperties: [VariableDeclSyntax] = memberBlock.members.compactMap { member in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return nil }
            guard let binding = varDecl.bindings.first else { return nil }
            // Skip computed properties (they declare an accessor block).
            if binding.accessorBlock != nil { return nil }
            return varDecl
        }

        var bodyLines: [String] = []

        for prop in storedProperties {
            guard let binding = prop.bindings.first,
                let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
            else { continue }
            let propName = pattern.identifier.text

            let attribute = Self.parseQueryAttribute(from: prop.attributes, in: context)

            switch attribute {
                case .ignore:
                    continue
                case .flag:
                    bodyLines.append("if \(propName) { Query(\"\(propName)\") }")
                case .key(let customKey):
                    bodyLines.append(
                        Self.emitLine(
                            propName: propName, key: customKey, type: binding.typeAnnotation?.type)
                    )
                case .none:
                    bodyLines.append(
                        Self.emitLine(
                            propName: propName, key: propName, type: binding.typeAnnotation?.type)
                    )
            }
        }

        let body: String
        if bodyLines.isEmpty {
            body = ""
        } else {
            body = bodyLines.joined(separator: "\n    ")
        }

        let extensionSource: DeclSyntax = """
            extension \(type.trimmed): URLBuilder.URLQueryRepresentable {
              @URLQueryBuilder
              public var urlQuery: [Query] {
                \(raw: body)
              }
            }
            """

        guard let extDecl = extensionSource.as(ExtensionDeclSyntax.self) else {
            return []
        }
        return [extDecl]
    }

    /// Emits a single body line for a stored property, choosing the right
    /// shape based on the syntactic type annotation when one is present.
    private static func emitLine(propName: String, key: String, type: TypeSyntax?) -> String {
        guard let type else {
            return "Query(\"\(key)\", \(propName))"
        }

        let typeText = type.trimmedDescription

        // Optional<T> or T? → if let binding
        if typeText.hasSuffix("?") || typeText.hasPrefix("Optional<") {
            return "if let \(propName) { Query(\"\(key)\", \(propName)) }"
        }

        // [T] or Array<T> or Set<T> → for-loop emitting one item per element
        if typeText.hasPrefix("[")
            || typeText.hasPrefix("Array<")
            || typeText.hasPrefix("Set<")
        {
            return "for element in \(propName) { Query(\"\(key)\", element) }"
        }

        return "Query(\"\(key)\", \(propName))"
    }

    /// Parses a `@Query(.key("…"))`, `@Query(.flag)`, or `@Query(.ignore)`
    /// peer attribute from a property's attribute list.
    private static func parseQueryAttribute(
        from attrList: AttributeListSyntax,
        in context: some MacroExpansionContext
    ) -> QueryAttributeKind? {
        for entry in attrList {
            guard let attribute = entry.as(AttributeSyntax.self) else { continue }
            let nameText = attribute.attributeName.trimmedDescription
            guard nameText == "Query" else { continue }

            guard case .argumentList(let args) = attribute.arguments,
                let firstArg = args.first
            else {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(attribute),
                        message: URLQueryMacroDiagnostic.malformedQueryAttribute
                    )
                )
                return nil
            }

            let expr = firstArg.expression
            let exprText = expr.trimmedDescription

            if exprText == ".ignore" {
                return .ignore
            }
            if exprText == ".flag" {
                return .flag
            }

            if let funcCall = expr.as(FunctionCallExprSyntax.self),
                let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
                memberAccess.declName.baseName.text == "key",
                let stringArg = funcCall.arguments.first,
                let stringLit = stringArg.expression.as(StringLiteralExprSyntax.self),
                let segment = stringLit.segments.first?.as(StringSegmentSyntax.self),
                stringLit.segments.count == 1
            {
                return .key(segment.content.text)
            }

            context.diagnose(
                Diagnostic(
                    node: Syntax(attribute),
                    message: URLQueryMacroDiagnostic.malformedQueryAttribute
                )
            )
            return nil
        }
        return nil
    }
}

internal enum QueryAttributeKind {
    case key(String)
    case flag
    case ignore
}

internal enum URLQueryMacroDiagnostic: String, DiagnosticMessage {
    case unsupportedDeclaration
    case malformedQueryAttribute

    var diagnosticID: MessageID {
        MessageID(domain: "URLBuilderMacros.URLQuery", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
            case .unsupportedDeclaration:
                return "@URLQuery can only be applied to a struct, class, or actor."
            case .malformedQueryAttribute:
                return
                    "@Query expects one of `.key(\"…\")`, `.flag`, or `.ignore` as its argument."
        }
    }
}
