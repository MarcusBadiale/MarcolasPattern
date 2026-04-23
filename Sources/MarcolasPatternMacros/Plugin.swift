//
//  Plugin.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MarcolasPatternPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MCProviderMacro.self,
        MCViewMacro.self,
    ]
}
