//
//  MCViewMacro.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct MCViewMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw MacroError.message("@MCView can only be applied to a struct")
        }

        let viewModelName = extractViewModelName(from: node)
        let providerName = "_\(viewModelName)Provider"

        let member: DeclSyntax = """
        @\(raw: viewModelName).\(raw: providerName) var data
        """

        return [member]
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
