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

    private static func validateAction(_ function: FunctionDeclSyntax) throws {
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
        let names = declaration.memberBlock.members.compactMap { member -> String? in
            if let variable = member.decl.as(VariableDeclSyntax.self), variable.attributes.hasTweak {
                return variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            }
            if let function = member.decl.as(FunctionDeclSyntax.self), function.attributes.hasTweak {
                return function.name.text
            }
            return nil
        }
        let access = declaration.modifiers.contains { $0.name.tokenKind == .keyword(.public) } ? "public " : ""
        let list = names.map { "\($0)Tweak" }.joined(separator: ", ")
        let store = node.arguments?.as(LabeledExprListSyntax.self)?
            .first { $0.label?.text == "store" }?.expression.trimmedDescription ?? ".shared"
        return [
            "\(raw: access)static let tweakStore: TweakStore = \(raw: store)",
            "\(raw: access)static let allTweaks: [any AnyTweak] = [\(raw: list)]",
        ]
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
        modifiers = variable.modifiers.prefixDescription
    }
}

private extension DeclModifierListSyntax {
    var isStatic: Bool { contains { $0.name.tokenKind == .keyword(.static) } }
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
