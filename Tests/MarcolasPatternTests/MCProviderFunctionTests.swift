import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros
#endif

// MARK: - Function Tests

final class MCProviderFunctionTests: XCTestCase {

    func testMultipleParamsFunction() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct EditorProvider {
                func updateItem(_ item: Item, newName: String) {
                    item.name = newName
                }
            }
            """,
            expandedSource: """
            struct EditorProvider {
                func updateItem(_ item: Item, newName: String) {
                    item.name = newName
                }

                /// Auto-generated data for `EditorProvider`.
                public struct EditorData: CustomDebugStringConvertible {
                    public let updateItem: (Item, String) -> Void
                    public var debugDescription: String {
                        "EditorData(updateItem: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    func updateItem(_ item: Item, newName: String) {
                        item.name = newName
                    }

                    var wrappedValue: EditorData {
                        EditorData(
                            updateItem: { [self] item, newName in
                                self.updateItem(item, newName: newName)
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    mutating func updateItem(_ item: Item, newName: String) {
                        item.name = newName
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

    func testAsyncFunction() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct FeedProvider {
                @State var items: [String] = []
                @State var isLoading: Bool = false

                func loadItems() async {
                    isLoading = true
                    items = await fetchItems()
                    isLoading = false
                }
            }
            """,
            expandedSource: """
            struct FeedProvider {
                @State var items: [String] = []
                @State var isLoading: Bool = false

                func loadItems() async {
                    isLoading = true
                    items = await fetchItems()
                    isLoading = false
                }

                /// Auto-generated data for `FeedProvider`.
                public struct FeedData: CustomDebugStringConvertible {
                    @Binding public var items: [String]
                    @Binding public var isLoading: Bool
                    public let loadItems: @Sendable () async -> Void
                    public var debugDescription: String {
                        "FeedData(items: \\(items), isLoading: \\(isLoading), loadItems: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @State var items: [String] = []

                    @State var isLoading: Bool = false

                    func loadItems() async {
                        isLoading = true
                        items = await fetchItems()
                        isLoading = false
                    }

                    var wrappedValue: FeedData {
                        FeedData(
                            items: $items,
                            isLoading: $isLoading,
                            loadItems: { [self] in
                                await self.loadItems()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var items: [String]

                    var isLoading: Bool

                    mutating func loadItems() async {
                        isLoading = true
                        items = await fetchItems()
                        isLoading = false
                    }

                    init(items: [String] = [], isLoading: Bool = false) {
                        self.items = items
                        self.isLoading = isLoading
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

    func testAsyncThrowsFunction() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct ProfileProvider {
                func saveProfile() async throws {
                    try await api.save()
                }
            }
            """,
            expandedSource: """
            struct ProfileProvider {
                func saveProfile() async throws {
                    try await api.save()
                }

                /// Auto-generated data for `ProfileProvider`.
                public struct ProfileData: CustomDebugStringConvertible {
                    public let saveProfile: @Sendable () async throws -> Void
                    public var debugDescription: String {
                        "ProfileData(saveProfile: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    func saveProfile() async throws {
                        try await api.save()
                    }

                    var wrappedValue: ProfileData {
                        ProfileData(
                            saveProfile: { [self] in
                                try await self.saveProfile()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    mutating func saveProfile() async throws {
                        try await api.save()
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

    func testSyncThrowsFunction() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct FormProvider {
                func validate() throws {
                    guard !name.isEmpty else { throw ValidationError.empty }
                }
            }
            """,
            expandedSource: """
            struct FormProvider {
                func validate() throws {
                    guard !name.isEmpty else { throw ValidationError.empty }
                }

                /// Auto-generated data for `FormProvider`.
                public struct FormData: CustomDebugStringConvertible {
                    public let validate: () throws -> Void
                    public var debugDescription: String {
                        "FormData(validate: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    func validate() throws {
                        guard !name.isEmpty else {
                            throw ValidationError.empty
                        }
                    }

                    var wrappedValue: FormData {
                        FormData(
                            validate: { [self] in
                                try self.validate()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    mutating func validate() throws {
                        guard !name.isEmpty else {
                            throw ValidationError.empty
                        }
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

    func testFunctionWithReturnType() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct CounterProvider {
                @State var count: Int = 0

                func getCount() -> Int {
                    return count
                }
            }
            """,
            expandedSource: """
            struct CounterProvider {
                @State var count: Int = 0

                func getCount() -> Int {
                    return count
                }

                /// Auto-generated data for `CounterProvider`.
                public struct CounterData: CustomDebugStringConvertible {
                    @Binding public var count: Int
                    public let getCount: () -> Int
                    public var debugDescription: String {
                        "CounterData(count: \\(count), getCount: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @State var count: Int = 0

                    func getCount() -> Int {
                        return count
                    }

                    var wrappedValue: CounterData {
                        CounterData(
                            count: $count,
                            getCount: { [self] in
                                self.getCount()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var count: Int

                    mutating func getCount() -> Int {
                        return count
                    }

                    init(count: Int = 0) {
                        self.count = count
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
