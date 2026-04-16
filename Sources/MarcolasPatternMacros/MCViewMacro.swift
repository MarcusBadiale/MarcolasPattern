//
//  MCViewMacro.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

// Sources/MarcolasPatternMacros/MCViewMacro.swift

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct MCViewMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.message("@MCView can only be applied to a struct")
        }

        let viewModelName = extractViewModelName(from: node)
        let bridgeName = "\(viewModelName)._\(viewModelName)Bridge"

        let ext: DeclSyntax = """
        extension \(type.trimmed): View {
            var body: some View {
                \(raw: bridgeName) { data in
                    ui(data: data)
                }
            }
        }
        """

        guard let extensionDecl = ext.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    private static func extractViewModelName(from node: AttributeSyntax) -> String {
        if let arguments = node.arguments,
           case let .argumentList(argList) = arguments,
           let firstArg = argList.first {
            let expr = firstArg.expression.trimmedDescription
            if expr.hasSuffix(".self") {
                return String(expr.dropLast(5))
            }
            return expr
        }
        return "UnknownViewModel"
    }
}
