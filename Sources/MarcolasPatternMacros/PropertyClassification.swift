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
    case bindable
    case computed
    case regular
}

// MARK: - Skip Reasons

enum PropertySkipReason {
    case noTypeAnnotationOrInferrable
    case computedWithoutType
    case unsupportedPattern
}

// MARK: - Classification Result

enum ClassificationResult {
    case classified(ClassifiedProperty)
    case skipped(name: String, reason: PropertySkipReason, node: Syntax)
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

    static func classify(member: MemberBlockItemSyntax) -> ClassificationResult? {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            return nil // Not a variable declaration — no diagnostic needed
        }

        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            let name = varDecl.bindings.first?.pattern.trimmedDescription ?? "unknown"
            return .skipped(name: name, reason: .unsupportedPattern, node: Syntax(varDecl))
        }

        let name = pattern.identifier.trimmedDescription
        let attributes = varDecl.attributes

        // Computed property detection
        if let accessorBlock = binding.accessorBlock {
            if case .getter = accessorBlock.accessors {
                guard let type = binding.typeAnnotation?.type else {
                    return .skipped(name: name, reason: .computedWithoutType, node: Syntax(varDecl))
                }
                return .classified(ClassifiedProperty(
                    kind: .computed,
                    name: name,
                    type: type,
                    binding: binding,
                    fullDecl: varDecl
                ))
            }
            if case let .accessors(accessorList) = accessorBlock.accessors {
                let kinds = accessorList.map { $0.accessorSpecifier.trimmedDescription }
                if kinds.contains("get") && !kinds.contains("set") &&
                   !kinds.contains("willSet") && !kinds.contains("didSet") {
                    guard let type = binding.typeAnnotation?.type else {
                        return .skipped(name: name, reason: .computedWithoutType, node: Syntax(varDecl))
                    }
                    return .classified(ClassifiedProperty(
                        kind: .computed,
                        name: name,
                        type: type,
                        binding: binding,
                        fullDecl: varDecl
                    ))
                }
            }
        }

        let wrapperName = findPropertyWrapper(in: attributes)

        // @Environment often omits type annotations (e.g. @Environment(\.modelContext) var modelContext).
        // When a metatype argument is present (e.g. @Environment(Navigator.self)), we extract the type.
        // Otherwise a placeholder type is used — the Bridge only needs originalSource for these.
        let type: TypeSyntax
        if let explicitType = binding.typeAnnotation?.type {
            type = explicitType
        } else if wrapperName == "Environment" {
            if let metatype = extractTypeFromEnvironmentMetatype(in: attributes) {
                type = metatype
            } else {
                type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Any")))
            }
        } else if let inferred = inferType(from: binding) {
            type = inferred
        } else {
            return .skipped(name: name, reason: .noTypeAnnotationOrInferrable, node: Syntax(varDecl))
        }

        let kind: PropertyKind
        switch wrapperName {
        case "Query": kind = .query
        case "State": kind = .state
        case "Environment": kind = .environment
        case "Bindable": kind = .bindable
        default: kind = .regular
        }

        return .classified(ClassifiedProperty(
            kind: kind,
            name: name,
            type: type,
            binding: binding,
            fullDecl: varDecl
        ))
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
        let knownWrappers: Set<String> = ["Query", "State", "Environment", "Bindable"]
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

    /// Extracts the type from `@Environment(Type.self)` metatype arguments.
    /// Returns `nil` for key-path arguments like `@Environment(\.keyPath)`.
    private static func extractTypeFromEnvironmentMetatype(in attributes: AttributeListSyntax) -> TypeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identType = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identType.name.trimmedDescription == "Environment" else { continue }

            // Match @Environment(Type.self) pattern
            if let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
               let firstArg = arguments.first,
               let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self),
               memberAccess.declName.baseName.trimmedDescription == "self",
               let base = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                let typeName = base.baseName.trimmedDescription
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier(typeName)))
            }
        }
        return nil
    }

    /// Tries to infer the type from the initializer expression.
    /// Handles patterns like `let x = Foo()`, `let x = Foo.init()`,
    /// `let x = Foo(arg: val)`, `let x = Foo.shared`, and common literals.
    private static func inferType(from binding: PatternBindingSyntax) -> TypeSyntax? {
        guard let initializer = binding.initializer?.value else { return nil }

        // Integer literal → Int
        if initializer.is(IntegerLiteralExprSyntax.self) {
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Int")))
        }

        // Float literal → Double
        if initializer.is(FloatLiteralExprSyntax.self) {
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Double")))
        }

        // String literal → String
        if initializer.is(StringLiteralExprSyntax.self) {
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
        }

        // Boolean literal → Bool
        if initializer.is(BooleanLiteralExprSyntax.self) {
            return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Bool")))
        }

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
