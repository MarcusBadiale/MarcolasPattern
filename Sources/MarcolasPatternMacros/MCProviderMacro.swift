//
//  MCProviderMacro.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftDiagnostics

public struct MCProviderMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.message("@MCProvider can only be applied to a struct")
        }

        let structName = structDecl.name.trimmedDescription
        let baseName = structName.hasSuffix("Provider")
            ? String(structName.dropLast("Provider".count))
            : structName
        let dataName = "\(baseName)Data"
        let providerName = "_DataWrapper"

        let classified = classifyMembers(structDecl)

        // Emit warnings for skipped properties
        for (name, reason, node) in classified.skipped {
            context.diagnose(Diagnostic(
                node: node,
                message: MacroDiagnosticMessage.propertySkipped(name: name, reason: reason)
            ))
        }

        let dataStruct = generateDataStruct(
            name: dataName,
            structName: structName,
            queryProps: classified.query,
            stateProps: classified.state,
            bindableProps: classified.bindable,
            computedProps: classified.computed,
            regularProps: classified.regular,
            functions: classified.functions
        )

        let provider = generateProvider(
            providerName: providerName,
            dataName: dataName,
            queryProps: classified.query,
            stateProps: classified.state,
            environmentProps: classified.environment,
            bindableProps: classified.bindable,
            computedProps: classified.computed,
            regularProps: classified.regular,
            functions: classified.functions
        )

        let mock = generateMock(
            queryProps: classified.query,
            stateProps: classified.state,
            environmentProps: classified.environment,
            bindableProps: classified.bindable,
            computedProps: classified.computed,
            regularProps: classified.regular,
            functions: classified.functions
        )

        return [dataStruct, provider, mock]
    }
}

// MARK: - Member Classification

private struct ClassifiedMembers {
    var query: [ClassifiedProperty] = []
    var state: [ClassifiedProperty] = []
    var environment: [ClassifiedProperty] = []
    var bindable: [ClassifiedProperty] = []
    var computed: [ClassifiedProperty] = []
    var regular: [ClassifiedProperty] = []
    var functions: [ClassifiedFunction] = []
    var skipped: [(name: String, reason: PropertySkipReason, node: Syntax)] = []
}

private func classifyMembers(_ structDecl: StructDeclSyntax) -> ClassifiedMembers {
    var result = ClassifiedMembers()

    for member in structDecl.memberBlock.members {
        if let classification = PropertyClassifier.classify(member: member) {
            switch classification {
            case .classified(let prop):
                switch prop.kind {
                case .query: result.query.append(prop)
                case .state: result.state.append(prop)
                case .environment: result.environment.append(prop)
                case .bindable: result.bindable.append(prop)
                case .computed: result.computed.append(prop)
                case .regular: result.regular.append(prop)
                }
            case .skipped(let name, let reason, let node):
                result.skipped.append((name: name, reason: reason, node: node))
            }
        }
        if let func_ = PropertyClassifier.classifyFunction(member: member) {
            result.functions.append(func_)
        }
    }

    return result
}

// MARK: - Data Struct Generation

private func generateDataStruct(
    name: String,
    structName: String,
    queryProps: [ClassifiedProperty],
    stateProps: [ClassifiedProperty],
    bindableProps: [ClassifiedProperty],
    computedProps: [ClassifiedProperty],
    regularProps: [ClassifiedProperty],
    functions: [ClassifiedFunction]
) -> DeclSyntax {
    var members: [String] = []

    for prop in queryProps {
        members.append("    public let \(prop.name): \(prop.type.trimmedDescription)")
    }
    for prop in stateProps {
        members.append("    @Binding public var \(prop.name): \(prop.type.trimmedDescription)")
    }
    for prop in bindableProps {
        members.append("    @Bindable public var \(prop.name): \(prop.type.trimmedDescription)")
    }
    for prop in computedProps {
        members.append("    public let \(prop.name): \(prop.type.trimmedDescription)")
    }
    for prop in regularProps {
        members.append("    public let \(prop.name): \(prop.type.trimmedDescription)")
    }
    for func_ in functions {
        members.append("    public let \(func_.name): \(closureType(for: func_))")
    }

    // Build debugDescription
    var debugParts: [String] = []
    let allProps = queryProps + stateProps + bindableProps + computedProps + regularProps
    for prop in allProps {
        if prop.type.is(OptionalTypeSyntax.self) || prop.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            debugParts.append("\(prop.name): \\(String(describing: \(prop.name)))")
        } else {
            debugParts.append("\(prop.name): \\(\(prop.name))")
        }
    }
    for func_ in functions {
        debugParts.append("\(func_.name): (closure)")
    }
    let debugBody = debugParts.joined(separator: ", ")

    return """
    /// Auto-generated data for `\(raw: structName)`.
    public struct \(raw: name): CustomDebugStringConvertible {
    \(raw: members.joined(separator: "\n"))
        public var debugDescription: String {
            "\(raw: name)(\(raw: debugBody))"
        }
    }
    """
}

// MARK: - Provider Generation (DynamicProperty)

private func generateProvider(
    providerName: String,
    dataName: String,
    queryProps: [ClassifiedProperty],
    stateProps: [ClassifiedProperty],
    environmentProps: [ClassifiedProperty],
    bindableProps: [ClassifiedProperty],
    computedProps: [ClassifiedProperty],
    regularProps: [ClassifiedProperty],
    functions: [ClassifiedFunction]
) -> DeclSyntax {
    var lines: [String] = []

    for prop in queryProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in stateProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in environmentProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in bindableProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in computedProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in regularProps {
        let keyword = prop.fullDecl.bindingSpecifier.trimmedDescription
        lines.append("    \(keyword) \(prop.name): \(prop.type.trimmedDescription)")
    }
    for func_ in functions {
        lines.append("    \(func_.originalSource)")
    }

    // Generate init for regular properties (enables dependency injection)
    if !regularProps.isEmpty {
        var initParams: [String] = []
        var initBody: [String] = []

        for prop in regularProps {
            let typeStr = prop.type.trimmedDescription
            if let initializer = prop.binding.initializer?.value {
                initParams.append("\(prop.name): \(typeStr) = \(initializer.trimmedDescription)")
            } else {
                initParams.append("\(prop.name): \(typeStr)")
            }
            initBody.append("        self.\(prop.name) = \(prop.name)")
        }

        lines.append("""
            init(\(initParams.joined(separator: ", "))) {
        \(initBody.joined(separator: "\n"))
            }
        """)
    }

    var assignments: [String] = []
    for prop in queryProps {
        assignments.append("            \(prop.name): \(prop.name)")
    }
    for prop in stateProps {
        assignments.append("            \(prop.name): $\(prop.name)")
    }
    for prop in bindableProps {
        assignments.append("            \(prop.name): \(prop.name)")
    }
    for prop in computedProps {
        assignments.append("            \(prop.name): \(prop.name)")
    }
    for prop in regularProps {
        assignments.append("            \(prop.name): \(prop.name)")
    }
    for func_ in functions {
        assignments.append("            \(func_.name): \(closureWrapper(for: func_))")
    }

    lines.append("""
        var wrappedValue: \(dataName) {
            \(dataName)(
    \(assignments.joined(separator: ",\n"))
            )
        }
    """)

    lines.append("    var projectedValue: Self { self }")

    let body = lines.joined(separator: "\n\n")

    return """
    @MainActor @propertyWrapper
    struct \(raw: providerName): DynamicProperty {
    \(raw: body)
    }
    """
}

// MARK: - Mock Generation (Testable)

private func generateMock(
    queryProps: [ClassifiedProperty],
    stateProps: [ClassifiedProperty],
    environmentProps: [ClassifiedProperty],
    bindableProps: [ClassifiedProperty],
    computedProps: [ClassifiedProperty],
    regularProps: [ClassifiedProperty],
    functions: [ClassifiedFunction]
) -> DeclSyntax {
    var members: [String] = []
    var requiredParams: [String] = []
    var optionalParams: [String] = []
    var initBody: [String] = []

    // @Query → var, required in init
    for prop in queryProps {
        let typeStr = prop.type.trimmedDescription
        members.append("    var \(prop.name): \(typeStr)")
        requiredParams.append("\(prop.name): \(typeStr)")
        initBody.append("        self.\(prop.name) = \(prop.name)")
    }

    // @Bindable → var, required in init
    for prop in bindableProps {
        let typeStr = prop.type.trimmedDescription
        members.append("    var \(prop.name): \(typeStr)")
        requiredParams.append("\(prop.name): \(typeStr)")
        initBody.append("        self.\(prop.name) = \(prop.name)")
    }

    // @Environment → var, required in init (only if explicitly typed)
    for prop in environmentProps {
        guard prop.binding.typeAnnotation != nil else { continue }
        let typeStr = prop.type.trimmedDescription
        members.append("    var \(prop.name): \(typeStr)")
        requiredParams.append("\(prop.name): \(typeStr)")
        initBody.append("        self.\(prop.name) = \(prop.name)")
    }

    // Regular → var, required in init (dependencies)
    for prop in regularProps {
        let typeStr = prop.type.trimmedDescription
        members.append("    var \(prop.name): \(typeStr)")
        requiredParams.append("\(prop.name): \(typeStr)")
        initBody.append("        self.\(prop.name) = \(prop.name)")
    }

    // @State → var with default in init (UI state)
    for prop in stateProps {
        let typeStr = prop.type.trimmedDescription
        members.append("    var \(prop.name): \(typeStr)")
        if let initializer = prop.binding.initializer?.value {
            optionalParams.append("\(prop.name): \(typeStr) = \(initializer.trimmedDescription)")
        } else {
            requiredParams.append("\(prop.name): \(typeStr)")
        }
        initBody.append("        self.\(prop.name) = \(prop.name)")
    }

    // Computed → copy as-is (no init param)
    for prop in computedProps {
        members.append("    \(prop.originalSource)")
    }

    // Functions → mutating func
    for func_ in functions {
        members.append("    mutating \(func_.originalSource)")
    }

    // Generate init: required params first, then optional with defaults
    let allParams = requiredParams + optionalParams
    if !allParams.isEmpty {
        members.append("""
            init(\(allParams.joined(separator: ", "))) {
        \(initBody.joined(separator: "\n"))
            }
        """)
    }

    let body = members.joined(separator: "\n\n")

    return """
    struct Mock {
    \(raw: body)
    }
    """
}

// MARK: - Closure Helpers

private func closureType(for func_: ClassifiedFunction) -> String {
    let paramsStr = func_.parameters.map { $0.type.trimmedDescription }.joined(separator: ", ")
    let returnStr = func_.returnType?.trimmedDescription ?? "Void"
    var modifiers = ""
    if func_.isAsync { modifiers += " async" }
    if func_.isThrows { modifiers += " throws" }
    // Only async closures need @Sendable (they cross actor boundaries).
    // Sync closures run on @MainActor and don't need it.
    let sendable = func_.isAsync ? "@Sendable " : ""
    return "\(sendable)(\(paramsStr))\(modifiers) -> \(returnStr)"
}

private func closureWrapper(for func_: ClassifiedFunction) -> String {
    let paramNames = func_.parameters.map {
        $0.secondName?.trimmedDescription ?? $0.firstName.trimmedDescription
    }
    let callArgs = func_.parameters.enumerated().map { (i, param) -> String in
        let firstName = param.firstName.trimmedDescription
        return firstName == "_" ? paramNames[i] : "\(firstName): \(paramNames[i])"
    }

    var prefix = ""
    if func_.isAsync { prefix += "await " }
    if func_.isThrows { prefix = "try \(prefix)" }

    let params = paramNames.joined(separator: ", ")
    let args = callArgs.joined(separator: ", ")
    let call = "\(prefix)self.\(func_.name)(\(args))"

    if paramNames.isEmpty {
        return "{ [self] in \(call) }"
    }
    return "{ [self] \(params) in \(call) }"
}
