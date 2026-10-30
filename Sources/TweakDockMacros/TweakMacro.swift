import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct TweakDockPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [TweakMacro.self, TweaksMacro.self]
}

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

public struct TweakMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let property = try TweakProperty(declaration)
        return [
            "get { \(raw: property.name)Tweak.value }",
            "set { \(raw: property.name)Tweak.value = newValue }",
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let arguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []

        if let function = declaration.as(FunctionDeclSyntax.self) {
            try validateAction(function)
            let modifiers = function.modifiers.prefixDescription
            return ["\(raw: modifiers)let \(raw: function.name.text)Tweak = TweakAction(\(arguments)) { \(raw: function.name.text)() }"]
        }

        // The accessor role reports invalid properties, so this role does not report them again.
        guard let property = try? TweakProperty(declaration) else { return [] }
        return ["\(raw: property.modifiers)let \(raw: property.name)Tweak = Tweak<\(property.type)>(\(arguments), store: tweakStore)"]
    }

    static func validateAction(_ function: FunctionDeclSyntax) throws {
        let name = function.name.text
        guard function.modifiers.isStatic else {
            throw MacroError("@Tweak method '\(name)' must be static.")
        }
        let signature = function.signature
        guard signature.parameterClause.parameters.isEmpty, signature.returnClause == nil,
              signature.effectSpecifiers == nil
        else {
            throw MacroError("@Tweak method '\(name)' must take no parameters, return nothing, and not throw or be async.")
        }
    }
}

public struct TweaksMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let entries = TweakEntry.entries(in: declaration.memberBlock.members)
        let access = declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) } ? "public " : ""
        let store = node.arguments?.as(LabeledExprListSyntax.self)?
            .first { $0.label?.text == "store" }?.expression.trimmedDescription ?? ".shared"
        return [
            "\(raw: access)static let tweakStore: TweakStore = \(raw: store)",
            "\(raw: access)static let allTweaks: [any AnyTweak] = \(raw: TweakEntry.listExpression(entries))",
        ]
    }
}

private enum TweakEntry {
    case tweak(String)
    case conditional([(header: String, entries: [TweakEntry])])

    static func entries(in members: MemberBlockItemListSyntax) -> [TweakEntry] {
        members.compactMap { member in
            if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
                let clauses = ifConfig.clauses.map { clause in
                    let header = [clause.poundKeyword.text, clause.condition?.trimmedDescription]
                        .compactMap { $0 }.joined(separator: " ")
                    guard case let .decls(members) = clause.elements else { return (header, [TweakEntry]()) }
                    return (header, entries(in: members))
                }
                return clauses.allSatisfy(\.1.isEmpty) ? nil : .conditional(clauses)
            }
            return tweakName(member.decl).map { .tweak("\($0)Tweak") }
        }
    }

    /// Returns only declarations that the peer role expands, so `allTweaks` never names a missing peer.
    private static func tweakName(_ declaration: DeclSyntax) -> String? {
        if let variable = declaration.as(VariableDeclSyntax.self), variable.attributes.hasTweak {
            return (try? TweakProperty(variable))?.name
        }
        if let function = declaration.as(FunctionDeclSyntax.self), function.attributes.hasTweak,
           (try? TweakMacro.validateAction(function)) != nil {
            return function.name.text
        }
        return nil
    }

    static func listExpression(_ entries: [TweakEntry]) -> String {
        let names = entries.compactMap { if case let .tweak(name) = $0 { name } else { nil } }
        guard names.count < entries.count else {
            return "[\(names.joined(separator: ", "))]"
        }
        let lines = ["var tweaks: [any AnyTweak] = []"] + entries.flatMap(appendLines) + ["return tweaks"]
        return "{\n\(lines.joined(separator: "\n"))\n}()"
    }

    private static func appendLines(_ entry: TweakEntry) -> [String] {
        switch entry {
        case let .tweak(name):
            ["tweaks.append(\(name))"]
        case let .conditional(clauses):
            clauses.flatMap { [$0.header] + $0.entries.flatMap(appendLines) } + ["#endif"]
        }
    }
}

private struct TweakProperty {
    let name: String
    let type: TypeSyntax
    let modifiers: String

    init(_ declaration: some DeclSyntaxProtocol) throws {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else {
            throw MacroError("@Tweak applies only to one 'static var' or a 'static func'.")
        }
        guard variable.modifiers.isStatic else {
            throw MacroError("@Tweak property '\(name)' must be static.")
        }
        guard binding.initializer == nil, binding.accessorBlock == nil else {
            throw MacroError("@Tweak property '\(name)' must not have a value. Use 'defaultValue' instead.")
        }
        guard let type = binding.typeAnnotation?.type.trimmed else {
            throw MacroError("@Tweak property '\(name)' must have a type annotation.")
        }
        self.name = name
        self.type = type
        modifiers = variable.modifiers.filter { $0.detail == nil }.prefixDescription
    }
}

private extension DeclModifierListSyntax {
    var isStatic: Bool { contains { $0.name.tokenKind == .keyword(.static) } }
}

private extension Sequence<DeclModifierSyntax> {
    var prefixDescription: String { map { "\($0.trimmedDescription) " }.joined() }
}

private extension AttributeListSyntax {
    var hasTweak: Bool {
        contains {
            let name = $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription
            return name == "Tweak" || name == "TweakDock.Tweak"
        }
    }
}
