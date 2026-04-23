import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros

let testMacros: [String: Macro.Type] = [
    "MCProvider": MCProviderMacro.self,
    "MCView": MCViewMacro.self,
]
#endif
