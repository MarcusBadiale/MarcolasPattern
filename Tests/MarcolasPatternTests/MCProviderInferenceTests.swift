import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros
#endif

// MARK: - Type Inference Tests

final class MCProviderInferenceTests: XCTestCase {

    func testInfersIntLiteral() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                let timeout = 30
            }
            """,
            expandedSource: """
            struct VM {
                let timeout = 30

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {
                    public let timeout: Int
                    public var debugDescription: String {
                        "VMData(timeout: \\(timeout))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let timeout: Int

                    init(timeout: Int = 30) {
                        self.timeout = timeout
                    }

                    var wrappedValue: VMData {
                        VMData(
                            timeout: timeout
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var timeout: Int

                    init(timeout: Int) {
                        self.timeout = timeout
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testInfersDoubleLiteral() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                let interval = 0.3
            }
            """,
            expandedSource: """
            struct VM {
                let interval = 0.3

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {
                    public let interval: Double
                    public var debugDescription: String {
                        "VMData(interval: \\(interval))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let interval: Double

                    init(interval: Double = 0.3) {
                        self.interval = interval
                    }

                    var wrappedValue: VMData {
                        VMData(
                            interval: interval
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var interval: Double

                    init(interval: Double) {
                        self.interval = interval
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testInfersStringLiteral() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                let placeholder = "Search..."
            }
            """,
            expandedSource: """
            struct VM {
                let placeholder = "Search..."

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {
                    public let placeholder: String
                    public var debugDescription: String {
                        "VMData(placeholder: \\(placeholder))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let placeholder: String

                    init(placeholder: String = "Search...") {
                        self.placeholder = placeholder
                    }

                    var wrappedValue: VMData {
                        VMData(
                            placeholder: placeholder
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var placeholder: String

                    init(placeholder: String) {
                        self.placeholder = placeholder
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testInfersBoolLiteral() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct VM {
                let verbose = true
            }
            """,
            expandedSource: """
            struct VM {
                let verbose = true

                /// Auto-generated data for `VM`.
                public struct VMData: CustomDebugStringConvertible {
                    public let verbose: Bool
                    public var debugDescription: String {
                        "VMData(verbose: \\(verbose))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let verbose: Bool

                    init(verbose: Bool = true) {
                        self.verbose = verbose
                    }

                    var wrappedValue: VMData {
                        VMData(
                            verbose: verbose
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var verbose: Bool

                    init(verbose: Bool) {
                        self.verbose = verbose
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
