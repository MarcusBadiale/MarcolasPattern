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

        let structName = extractStructName(from: node)
        let baseName = structName.hasSuffix("Provider")
            ? String(structName.dropLast("Provider".count))
            : structName
        let dataName = "\(baseName)Data"

        let member: DeclSyntax = """
        @\(raw: structName)._DataWrapper var data: \(raw: structName).\(raw: dataName)
        """

        return [member]
    }

    private static func extractStructName(from node: AttributeSyntax) -> String {
        if let arguments = node.arguments,
           case let .argumentList(argList) = arguments,
           let firstArg = argList.first {
            let expr = firstArg.expression.trimmedDescription
            if expr.hasSuffix(".self") {
                return String(expr.dropLast(5))
            }
            return expr
        }
        return "UnknownProvider"
    }
}
