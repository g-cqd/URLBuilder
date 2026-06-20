import ADFMacroSupport
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@URLQuery` synthesizes `URLQueryRepresentable` conformance by reading
/// stored properties of a struct/class/actor.
///
/// Per-property configuration uses the peer macro `@Query`:
///   • `@Query(.key("custom_name"))` overrides the rendered key.
///   • `@Query(.flag)` renders a `Bool` property as a value-less flag.
///   • `@Query(.ignore)` excludes the property from the synthesis.
///
/// Shape is inferred structurally from each binding's `TypeSyntax`:
///   • scalars render as `Query(key, value)`;
///   • a single optional layer unwraps with `if let`;
///   • `[T]` / `Array<T>` and `Set<T>` unfold to one item per element
///     (`Set` sorted for a deterministic URL);
///   • `static`/`class`/`lazy` storage and computed properties are skipped,
///     while `willSet`/`didSet` observers are kept.
///
/// Shapes that have no canonical unfold are diagnosed rather than guessed:
/// dictionaries, nested optionals, and an un-annotated collection literal
/// (which would otherwise silently JSON-encode).
struct URLQueryMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let memberBlock: MemberBlockSyntax
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            memberBlock = structDecl.memberBlock
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            memberBlock = classDecl.memberBlock
        } else if let actorDecl = declaration.as(ActorDeclSyntax.self) {
            memberBlock = actorDecl.memberBlock
        } else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: URLQueryMacroDiagnostic.unsupportedDeclaration
                )
            )
            return []
        }

        var bodyLines: [String] = []

        for member in memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

            // M1 — a `static`/`class` member is type-level state, and `lazy` is
            // computed on first access; neither is per-instance query state.
            if Self.isTypeLevelOrLazy(varDecl) { continue }

            let attribute = Self.parseQueryAttribute(from: varDecl.attributes, in: context)

            let bindings = Array(varDecl.bindings)
            for index in bindings.indices {
                let binding = bindings[index]

                // M6 — keep stored properties, including those with `willSet`/
                // `didSet` observers; skip only computed properties.
                guard Self.isStoredBinding(binding) else { continue }
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    continue
                }

                let name = Self.bareIdentifier(pattern.identifier.text)
                // M7 — a trailing annotation (`let a, b: Int`) types every earlier
                // binding that has neither its own annotation nor initializer.
                let resolvedType = Self.resolvedType(at: index, in: bindings)

                switch attribute {
                    case .ignore:
                        continue
                    case .flag:
                        // `.flag` renders a value-less item gated on a Bool
                        // condition (`if name { Query("name") }`). Pairing it
                        // with a non-Bool property would emit a
                        // non-Bool-condition error pointing at generated code, so
                        // diagnose it at the user's declaration instead — matching
                        // how every other unsupported shape is reported.
                        if let line = Self.flagLine(
                            name: name,
                            type: resolvedType,
                            node: binding,
                            in: context
                        ) {
                            bodyLines.append(line)
                        }
                    case .key(let customKey):
                        if let line = Self.emitLine(
                            name: name,
                            key: customKey,
                            type: resolvedType,
                            initializer: binding.initializer,
                            node: binding,
                            in: context
                        ) {
                            bodyLines.append(line)
                        }
                    case .none:
                        if let line = Self.emitLine(
                            name: name,
                            key: name,
                            type: resolvedType,
                            initializer: binding.initializer,
                            node: binding,
                            in: context
                        ) {
                            bodyLines.append(line)
                        }
                }
            }
        }

        let body = bodyLines.isEmpty ? "" : bodyLines.joined(separator: "\n    ")

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

    /// Emits a single body line for a stored property, choosing the right shape
    /// from the structural classification of its type annotation.
    ///
    /// Returns `nil` when the binding is diagnosed (dictionary, nested optional,
    /// or an un-annotated collection literal) — fail-fast rather than guessing a
    /// rendering.
    private static func emitLine(
        name: String,
        key: String,
        type: TypeSyntax?,
        initializer: InitializerClauseSyntax?,
        node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> String? {
        let keyLiteral = swiftStringLiteral(key)
        let value = escapedIdentifier(name)

        guard let type else {
            // M4 — without an annotation a collection literal would route through
            // the scalar/JSON path (`?tags=[…]`) instead of unfolding. Require an
            // explicit `[T]` / `Set<T>` annotation so the intent is unambiguous.
            if let initializer, isCollectionLiteral(initializer.value) {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(node),
                        message: URLQueryMacroDiagnostic.requiresTypeAnnotation
                    )
                )
                return nil
            }
            return "Query(\(keyLiteral), \(value))"
        }

        switch classify(type) {
            case .scalar:
                return "Query(\(keyLiteral), \(value))"
            case .array:
                return "for element in \(value) { Query(\(keyLiteral), element) }"
            case .set:
                return setLine(over: value, keyLiteral: keyLiteral)
            case .optionalScalar:
                return "if let \(value) { Query(\(keyLiteral), \(value)) }"
            case .optionalArray:
                return "if let \(value) { for element in \(value) { Query(\(keyLiteral), element) } }"
            case .optionalSet:
                return "if let \(value) { \(setLine(over: value, keyLiteral: keyLiteral)) }"
            case .dictionary:
                context.diagnose(
                    Diagnostic(
                        node: Syntax(type),
                        message: URLQueryMacroDiagnostic.unsupportedDictionary
                    )
                )
                return nil
            case .nestedOptional:
                context.diagnose(
                    Diagnostic(
                        node: Syntax(type),
                        message: URLQueryMacroDiagnostic.unsupportedNestedOptional
                    )
                )
                return nil
        }
    }

    /// Emits a value-less flag: `if name { Query("name") }`.
    ///
    /// `.flag` requires a `Bool`/`Bool?` property: the emitted `if name { … }`
    /// gates the item on a Bool condition. When paired with any other type the
    /// generated condition would not compile, so the mismatch is diagnosed at the
    /// user's declaration (returning `nil`) instead of emitting code that fails to
    /// compile with an error pointing at synthesized source.
    private static func flagLine(
        name: String,
        type: TypeSyntax?,
        node: some SyntaxProtocol,
        in context: some MacroExpansionContext
    ) -> String? {
        guard let type, isBoolType(type) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: URLQueryMacroDiagnostic.flagRequiresBool
                )
            )
            return nil
        }
        return "if \(escapedIdentifier(name)) { Query(\(swiftStringLiteral(name))) }"
    }

    /// Whether `type` is `Bool` or `Bool?` (one optional layer peeled).
    ///
    /// A nested optional (`Bool??`) is rejected: after a single `if name` unwrap
    /// the condition would still be optional, which is the same non-Bool-condition
    /// failure `.flag` exists to prevent.
    private static func isBoolType(_ type: TypeSyntax) -> Bool {
        let core = optionalInner(type) ?? type
        guard optionalInner(core) == nil else {
            return false
        }
        return core.as(IdentifierTypeSyntax.self)?.name.text == "Bool"
    }

    /// Emits a sorted `Set` unfold.
    ///
    /// The sort key is each element's `String(describing:)` form, so iteration is
    /// lexicographic and stable across runs — not numeric (a set of `1, 2, 10`
    /// renders as `1`, `10`, `2`). Determinism is what matters here (HMAC
    /// signing, cache keys, snapshot tests), not numeric ordering.
    private static func setLine(over value: String, keyLiteral: String) -> String {
        "for element in \(value).sorted(by: { String(describing: $0) < String(describing: $1) }) "
            + "{ Query(\(keyLiteral), element) }"
    }

    // MARK: - Structural classification

    private enum Classification {
        case scalar
        case array
        case set
        case optionalScalar
        case optionalArray
        case optionalSet
        case dictionary
        case nestedOptional
    }

    private enum CoreKind {
        case scalar
        case array
        case set
        case dictionary
    }

    /// Classifies a binding's type into an emission shape.
    ///
    /// At most one optional layer is peeled; a second layer (`Int??`) is reported
    /// as `nestedOptional` for diagnosis. The classification is flat — no
    /// recursion — because the supported shapes are at most one optional wrapping
    /// one collection.
    private static func classify(_ type: TypeSyntax) -> Classification {
        if let inner = optionalInner(type) {
            if optionalInner(inner) != nil {
                return .nestedOptional
            }
            switch coreKind(inner) {
                case .scalar: return .optionalScalar
                case .array: return .optionalArray
                case .set: return .optionalSet
                case .dictionary: return .dictionary
            }
        }

        switch coreKind(type) {
            case .scalar: return .scalar
            case .array: return .array
            case .set: return .set
            case .dictionary: return .dictionary
        }
    }

    /// Returns the wrapped type when `type` is `T?` or `Optional<T>`.
    private static func optionalInner(_ type: TypeSyntax) -> TypeSyntax? {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return optional.wrappedType
        }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional" {
            return firstGenericArgument(of: identifier)
        }
        return nil
    }

    /// Classifies a non-optional type as a scalar, array, set, or dictionary.
    private static func coreKind(_ type: TypeSyntax) -> CoreKind {
        if type.is(ArrayTypeSyntax.self) {
            return .array
        }
        if type.is(DictionaryTypeSyntax.self) {
            return .dictionary
        }
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            switch identifier.name.text {
                case "Array": return .array
                case "Set": return .set
                case "Dictionary": return .dictionary
                default: return .scalar
            }
        }
        return .scalar
    }

    /// Extracts the first generic argument type (`Optional<T>` → `T`).
    private static func firstGenericArgument(of identifier: IdentifierTypeSyntax) -> TypeSyntax? {
        guard let argument = identifier.genericArgumentClause?.arguments.first else {
            return nil
        }
        if case .type(let type) = argument.argument {
            return type
        }
        return nil
    }

    /// Whether an initializer expression is an array or dictionary literal.
    private static func isCollectionLiteral(_ expression: ExprSyntax) -> Bool {
        expression.is(ArrayExprSyntax.self) || expression.is(DictionaryExprSyntax.self)
    }
}

// Binding inspection (stored-vs-computed, type-level/lazy skipping, shared trailing-annotation
// resolution) and identifier / `@Query` attribute parsing for `URLQueryMacro`. Split from the macro
// type body to stay within the size/complexity gate.
extension URLQueryMacro {
    // MARK: - Binding inspection

    /// Whether the declaration is `static`/`class` (type-level) or `lazy`.
    private static func isTypeLevelOrLazy(_ varDecl: VariableDeclSyntax) -> Bool {
        varDecl.modifiers.contains { modifier in
            switch modifier.name.tokenKind {
                case .keyword(.static), .keyword(.class), .keyword(.lazy):
                    return true
                default:
                    return false
            }
        }
    }

    /// Whether a binding is stored.
    ///
    /// A binding with no accessor block is stored. A binding whose accessors are
    /// only `willSet`/`didSet` observers is still stored; any `get`/`_read`/
    /// `_modify`/address accessor (or a single-expression getter) is computed.
    private static func isStoredBinding(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else {
            return true
        }
        switch accessorBlock.accessors {
            case .getter:
                return false
            case .accessors(let accessors):
                return accessors.allSatisfy { accessor in
                    switch accessor.accessorSpecifier.tokenKind {
                        case .keyword(.didSet), .keyword(.willSet):
                            return true
                        default:
                            return false
                    }
                }
        }
    }

    /// Resolves a binding's effective type, propagating a shared trailing
    /// annotation (`let a, b: Int`) to earlier bindings that have neither their
    /// own annotation nor their own initializer.
    private static func resolvedType(
        at index: Int,
        in bindings: [PatternBindingSyntax]
    ) -> TypeSyntax? {
        if let own = bindings[index].typeAnnotation?.type {
            return own
        }
        // A binding with its own initializer is independently typed and does not
        // borrow a later binding's trailing annotation.
        if bindings[index].initializer != nil {
            return nil
        }
        var cursor = index + 1
        while cursor < bindings.count {
            if let type = bindings[cursor].typeAnnotation?.type {
                return type
            }
            if bindings[cursor].initializer != nil {
                return nil
            }
            cursor += 1
        }
        return nil
    }

    // MARK: - Identifier and literal rendering

    /// Strips surrounding backticks from a raw identifier token's text.
    private static func bareIdentifier(_ text: String) -> String {
        if text.count >= 2, text.hasPrefix("`"), text.hasSuffix("`") {
            return String(text.dropFirst().dropLast())
        }
        return text
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
                stringLit.segments.count == 1,
                // The decoded literal value (escapes resolved); `nil` for an
                // interpolated key, which is then rejected as malformed below.
                let keyValue = stringLit.representedLiteralValue
            {
                return .key(keyValue)
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
    case unsupportedDictionary
    case requiresTypeAnnotation
    case unsupportedNestedOptional
    case flagRequiresBool

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
            case .unsupportedDictionary:
                return
                    "@URLQuery does not support dictionary properties — a dictionary has no canonical "
                    + "query unfold. Encode it explicitly with a custom URLQueryRepresentable, or "
                    + "exclude it with @Query(.ignore)."
            case .requiresTypeAnnotation:
                return
                    "@URLQuery needs an explicit type annotation on a collection property (e.g. "
                    + "`let tags: [String]`) so it can unfold to repeated query items instead of "
                    + "encoding the literal."
            case .unsupportedNestedOptional:
                return
                    "@URLQuery does not support nested optionals — flatten to a single optional, or "
                    + "exclude it with @Query(.ignore)."
            case .flagRequiresBool:
                return
                    "@Query(.flag) requires a Bool property — `.flag` renders a value-less query "
                    + "item gated on the property's truth value. Use a Bool/Bool? property, or drop "
                    + "`.flag` to render the value."
        }
    }
}
