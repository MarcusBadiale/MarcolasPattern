//
//  PropertyClassification.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftSyntax

// MARK: - Property Kind

enum PropertyKind {
    case query
    case state
    case environment
    case computed
    case regular
}

// MARK: - Classified Property

struct ClassifiedProperty {
    let kind: PropertyKind
    let name: String
    let type: TypeSyntax
    let binding: PatternBindingSyntax
    let fullDecl: VariableDeclSyntax

    /// The complete original declaration source (attributes + var + type + initializer)
    /// Used by the Bridge to replicate @Query/@State/@Environment exactly as written.
    var originalSource: String {
        fullDecl.trimmedDescription
    }
}

// MARK: - Classified Function

struct ClassifiedFunction {
    let name: String
    let parameters: FunctionParameterListSyntax
    let returnType: TypeSyntax?
    let isAsync: Bool
    let isThrows: Bool
    let decl: FunctionDeclSyntax

    var originalSource: String {
        decl.trimmedDescription
    }
}

// MARK: - Classification Logic

struct PropertyClassifier {

    static func classify(member: MemberBlockItemSyntax) -> ClassifiedProperty? {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else { return nil }

        let name = pattern.identifier.trimmedDescription
        let attributes = varDecl.attributes

        // Computed property detection
        if let accessorBlock = binding.accessorBlock {
            if case .getter = accessorBlock.accessors {
                guard let type = binding.typeAnnotation?.type else { return nil }
                return ClassifiedProperty(
                    kind: .computed,
                    name: name,
                    type: type,
                    binding: binding,
                    fullDecl: varDecl
                )
            }
            if case let .accessors(accessorList) = accessorBlock.accessors {
                let kinds = accessorList.map { $0.accessorSpecifier.trimmedDescription }
                if kinds.contains("get") && !kinds.contains("set") &&
                   !kinds.contains("willSet") && !kinds.contains("didSet") {
                    guard let type = binding.typeAnnotation?.type else { return nil }
                    return ClassifiedProperty(
                        kind: .computed,
                        name: name,
                        type: type,
                        binding: binding,
                        fullDecl: varDecl
                    )
                }
            }
        }

        let wrapperName = findPropertyWrapper(in: attributes)

        // @Environment often omits type annotations (e.g. @Environment(\.modelContext) var modelContext).
        // The Bridge only needs originalSource for these, so a placeholder type is fine.
        let type: TypeSyntax
        if let explicitType = binding.typeAnnotation?.type {
            type = explicitType
        } else if wrapperName == "Environment" {
            type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Any")))
        } else if let inferred = inferType(from: binding) {
            type = inferred
        } else {
            return nil
        }

        let kind: PropertyKind
        switch wrapperName {
        case "Query": kind = .query
        case "State": kind = .state
        case "Environment": kind = .environment
        default: kind = .regular
        }

        return ClassifiedProperty(
            kind: kind,
            name: name,
            type: type,
            binding: binding,
            fullDecl: varDecl
        )
    }

    static func classifyFunction(member: MemberBlockItemSyntax) -> ClassifiedFunction? {
        guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { return nil }

        return ClassifiedFunction(
            name: funcDecl.name.trimmedDescription,
            parameters: funcDecl.signature.parameterClause.parameters,
            returnType: funcDecl.signature.returnClause?.type,
            isAsync: funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil,
            isThrows: funcDecl.signature.effectSpecifiers?.throwsClause != nil,
            decl: funcDecl
        )
    }

    // MARK: - Helpers

    private static func findPropertyWrapper(in attributes: AttributeListSyntax) -> String? {
        let knownWrappers: Set<String> = ["Query", "State", "Environment"]
        for attribute in attributes {
            if let attr = attribute.as(AttributeSyntax.self),
               let identType = attr.attributeName.as(IdentifierTypeSyntax.self) {
                let name = identType.name.trimmedDescription
                if knownWrappers.contains(name) {
                    return name
                }
            }
        }
        return nil
    }

    /// Tries to infer the type from the initializer expression.
    /// Handles patterns like `let x = Foo()`, `let x = Foo.init()`,
    /// `let x = Foo(arg: val)`, and `let x = Foo.shared`.
    private static func inferType(from binding: PatternBindingSyntax) -> TypeSyntax? {
        guard let initializer = binding.initializer?.value else { return nil }

        // `Foo()` or `Foo(arg: val)` — FunctionCallExpr with callee being an identifier
        if let call = initializer.as(FunctionCallExprSyntax.self) {
            // `Foo(...)` — callee is a DeclReferenceExpr
            if let ref = call.calledExpression.as(DeclReferenceExprSyntax.self) {
                let name = ref.baseName.trimmedDescription
                if name.first?.isUppercase == true {
                    return TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
                }
            }
            // `Foo.init(...)` — callee is a MemberAccessExpr
            if let member = call.calledExpression.as(MemberAccessExprSyntax.self),
               member.declName.baseName.trimmedDescription == "init",
               let base = member.base?.as(DeclReferenceExprSyntax.self) {
                let name = base.baseName.trimmedDescription
                if name.first?.isUppercase == true {
                    return TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
                }
            }
        }

        // `Foo.shared` or `Foo.default` — MemberAccessExpr with uppercase base
        if let member = initializer.as(MemberAccessExprSyntax.self),
           let base = member.base?.as(DeclReferenceExprSyntax.self) {
            let name = base.baseName.trimmedDescription
            if name.first?.isUppercase == true {
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
            }
        }

        return nil
    }
}
