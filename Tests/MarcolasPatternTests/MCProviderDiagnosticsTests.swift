import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros
#endif

// MARK: - Diagnostics & Edge Case Tests

final class MCProviderDiagnosticsTests: XCTestCase {

    func testWarnsOnUninferrableProperty() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                let retries = someFunction()
            }
            """,
            expandedSource: """
            struct VM {
                let retries = someFunction()

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {

                    public var debugDescription: String {
                        "VMData()"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    var wrappedValue: VMData {
                        VMData(

                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {

                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'retries' was skipped: add an explicit type annotation or use a recognizable initializer (e.g. let x: MyType = ...). It will not appear in the Data struct.",
                    line: 3,
                    column: 5,
                    severity: .warning
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testWarnsOnMultipleSkippedProperties() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                @State var name: String = ""
                let retries = someFunction()
                let config = getConfig()
            }
            """,
            expandedSource: """
            struct VM {
                @State var name: String = ""
                let retries = someFunction()
                let config = getConfig()

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {
                    @Binding public var name: String
                    public var debugDescription: String {
                        "VMData(name: \\(name))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @State var name: String = ""

                    var wrappedValue: VMData {
                        VMData(
                            name: $name
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var name: String

                    init(name: String = "") {
                        self.name = name
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'retries' was skipped: add an explicit type annotation or use a recognizable initializer (e.g. let x: MyType = ...). It will not appear in the Data struct.",
                    line: 4,
                    column: 5,
                    severity: .warning
                ),
                DiagnosticSpec(
                    message: "'config' was skipped: add an explicit type annotation or use a recognizable initializer (e.g. let x: MyType = ...). It will not appear in the Data struct.",
                    line: 5,
                    column: 5,
                    severity: .warning
                ),
            ],
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
            @MCProvider
            class NotAStruct {
                @State var x: Int = 0
            }
            """,
            expandedSource: """
            class NotAStruct {
                @State var x: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@MCProvider can only be applied to a struct", line: 1, column: 1),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
