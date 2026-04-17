//
//  MCViewModelMacro.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct MCViewModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.message("@MCViewModel can only be applied to a struct")
        }

        let structName = structDecl.name.trimmedDescription
        let dataName = "\(structName)Data"
        let providerName = "_\(structName)Provider"

        let classified = classifyMembers(structDecl)

        let dataStruct = generateDataStruct(
            name: dataName,
            queryProps: classified.query,
            stateProps: classified.state,
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
            computedProps: classified.computed,
            regularProps: classified.regular,
            functions: classified.functions
        )

        return [dataStruct, provider]
    }
}

// MARK: - Member Classification

private struct ClassifiedMembers {
    var query: [ClassifiedProperty] = []
    var state: [ClassifiedProperty] = []
    var environment: [ClassifiedProperty] = []
    var computed: [ClassifiedProperty] = []
    var regular: [ClassifiedProperty] = []
    var functions: [ClassifiedFunction] = []
}

private func classifyMembers(_ structDecl: StructDeclSyntax) -> ClassifiedMembers {
    var result = ClassifiedMembers()

    for member in structDecl.memberBlock.members {
        if let prop = PropertyClassifier.classify(member: member) {
            switch prop.kind {
            case .query: result.query.append(prop)
            case .state: result.state.append(prop)
            case .environment: result.environment.append(prop)
            case .computed: result.computed.append(prop)
            case .regular: result.regular.append(prop)
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
    queryProps: [ClassifiedProperty],
    stateProps: [ClassifiedProperty],
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
    for prop in computedProps {
        members.append("    public let \(prop.name): \(prop.type.trimmedDescription)")
    }
    for prop in regularProps {
        members.append("    public let \(prop.name): \(prop.type.trimmedDescription)")
    }
    for func_ in functions {
        members.append("    public let \(func_.name): \(closureType(for: func_))")
    }

    return """
    public struct \(raw: name) {
    \(raw: members.joined(separator: "\n"))
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
    for prop in computedProps {
        lines.append("    \(prop.originalSource)")
    }
    for prop in regularProps {
        lines.append("    \(prop.originalSource)")
    }
    for func_ in functions {
        lines.append("    \(func_.originalSource)")
    }

    var assignments: [String] = []
    for prop in queryProps {
        assignments.append("            \(prop.name): \(prop.name)")
    }
    for prop in stateProps {
        assignments.append("            \(prop.name): $\(prop.name)")
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
    @propertyWrapper
    struct \(raw: providerName): DynamicProperty {
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
    return "@Sendable (\(paramsStr))\(modifiers) -> \(returnStr)"
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

    // Async functions don't need MainActor.assumeIsolated — the `await`
    // handles actor hopping automatically. Sync functions do need it
    // because MainActor.assumeIsolated doesn't accept async closures.
    if func_.isAsync {
        if paramNames.isEmpty {
            return "{ [self] in \(call) }"
        }
        return "{ [self] \(params) in \(call) }"
    }

    if paramNames.isEmpty {
        return "{ [self] in MainActor.assumeIsolated { \(call) } }"
    }
    return "{ [self] \(params) in MainActor.assumeIsolated { \(call) } }"
}
