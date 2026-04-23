import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros
#endif

final class MCViewMacroTests: XCTestCase {

    func testGeneratesDataProperty() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCView(HomeProvider.self)
            struct HomeView: View {
                var body: some View {
                    Text("Hello")
                }
            }
            """,
            expandedSource: """
            struct HomeView: View {
                var body: some View {
                    Text("Hello")
                }

                @HomeProvider._DataWrapper var data
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testRejectsClass() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCView(HomeProvider.self)
            class NotAStruct {
            }
            """,
            expandedSource: """
            class NotAStruct {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@MCView can only be applied to a struct", line: 1, column: 1)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
