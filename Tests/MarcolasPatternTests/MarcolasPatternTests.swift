// Tests/MarcolasPatternTests/MarcolasPatternTests.swift

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros

let testMacros: [String: Macro.Type] = [
    "MCViewModel": MCViewModelMacro.self,
    "MCView": MCViewMacro.self,
]
#endif

// MARK: - @MCViewModel Tests

final class MCViewModelMacroTests: XCTestCase {

    func testGeneratesDataStructAndProvider() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
            struct HomeViewModel {
                @Query var items: [Item]
                @State var searchText: String = ""
                @Environment(\\.modelContext) var modelContext

                var filteredItems: [Item] {
                    items.filter { $0.name.contains(searchText) }
                }

                func deleteItem(_ item: Item) {
                    modelContext.delete(item)
                }
            }
            """,
            expandedSource: """
            struct HomeViewModel {
                @Query var items: [Item]
                @State var searchText: String = ""
                @Environment(\\.modelContext) var modelContext

                var filteredItems: [Item] {
                    items.filter { $0.name.contains(searchText) }
                }

                func deleteItem(_ item: Item) {
                    modelContext.delete(item)
                }

                public struct HomeViewModelData {
                    public let items: [Item]
                    @Binding public var searchText: String
                    public let filteredItems: [Item]
                    public let deleteItem: @Sendable (Item) -> Void
                }

                @propertyWrapper
                struct _HomeViewModelProvider: DynamicProperty {
                    @Query var items: [Item]

                    @State var searchText: String = ""

                    @Environment(\\.modelContext) var modelContext

                    var filteredItems: [Item] {
                        items.filter {
                            $0.name.contains(searchText)
                        }
                    }

                    func deleteItem(_ item: Item) {
                        modelContext.delete(item)
                    }

                    var wrappedValue: HomeViewModelData {
                        HomeViewModelData(
                            items: items,
                            searchText: $searchText,
                            filteredItems: filteredItems,
                            deleteItem: { [self] item in
                                MainActor.assumeIsolated {
                                    self.deleteItem(item)
                                }
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
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

    func testOnlyStateProperties() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
            struct SettingsViewModel {
                @State var isDarkMode: Bool = false
                @State var fontSize: Double = 14.0
            }
            """,
            expandedSource: """
            struct SettingsViewModel {
                @State var isDarkMode: Bool = false
                @State var fontSize: Double = 14.0

                public struct SettingsViewModelData {
                    @Binding public var isDarkMode: Bool
                    @Binding public var fontSize: Double
                }

                @propertyWrapper
                struct _SettingsViewModelProvider: DynamicProperty {
                    @State var isDarkMode: Bool = false

                    @State var fontSize: Double = 14.0

                    var wrappedValue: SettingsViewModelData {
                        SettingsViewModelData(
                            isDarkMode: $isDarkMode,
                            fontSize: $fontSize
                        )
                    }

                    var projectedValue: Self {
                        self
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

    func testMultipleParamsFunction() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
            struct EditorViewModel {
                func updateItem(_ item: Item, newName: String) {
                    item.name = newName
                }
            }
            """,
            expandedSource: """
            struct EditorViewModel {
                func updateItem(_ item: Item, newName: String) {
                    item.name = newName
                }

                public struct EditorViewModelData {
                    public let updateItem: @Sendable (Item, String) -> Void
                }

                @propertyWrapper
                struct _EditorViewModelProvider: DynamicProperty {
                    func updateItem(_ item: Item, newName: String) {
                        item.name = newName
                    }

                    var wrappedValue: EditorViewModelData {
                        EditorViewModelData(
                            updateItem: { [self] item, newName in
                                MainActor.assumeIsolated {
                                    self.updateItem(item, newName: newName)
                                }
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
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
            @MCViewModel
            struct FeedViewModel {
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
            struct FeedViewModel {
                @State var items: [String] = []
                @State var isLoading: Bool = false

                func loadItems() async {
                    isLoading = true
                    items = await fetchItems()
                    isLoading = false
                }

                public struct FeedViewModelData {
                    @Binding public var items: [String]
                    @Binding public var isLoading: Bool
                    public let loadItems: @Sendable () async -> Void
                }

                @propertyWrapper
                struct _FeedViewModelProvider: DynamicProperty {
                    @State var items: [String] = []

                    @State var isLoading: Bool = false

                    func loadItems() async {
                        isLoading = true
                        items = await fetchItems()
                        isLoading = false
                    }

                    var wrappedValue: FeedViewModelData {
                        FeedViewModelData(
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
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testRegularPropertyWithExplicitType() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
            struct HomeViewModel {
                let repository: TodoRepository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }
            }
            """,
            expandedSource: """
            struct HomeViewModel {
                let repository: TodoRepository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }

                public struct HomeViewModelData {
                    public let repository: TodoRepository
                    public let load: @Sendable () async -> Void
                }

                @propertyWrapper
                struct _HomeViewModelProvider: DynamicProperty {
                    let repository: TodoRepository = TodoRepository()

                    func load() async {
                        await repository.fetch()
                    }

                    var wrappedValue: HomeViewModelData {
                        HomeViewModelData(
                            repository: repository,
                            load: { [self] in
                                await self.load()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
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

    func testRegularPropertyWithInferredType() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
            struct HomeViewModel {
                let repository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }
            }
            """,
            expandedSource: """
            struct HomeViewModel {
                let repository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }

                public struct HomeViewModelData {
                    public let repository: TodoRepository
                    public let load: @Sendable () async -> Void
                }

                @propertyWrapper
                struct _HomeViewModelProvider: DynamicProperty {
                    let repository = TodoRepository()

                    func load() async {
                        await repository.fetch()
                    }

                    var wrappedValue: HomeViewModelData {
                        HomeViewModelData(
                            repository: repository,
                            load: { [self] in
                                await self.load()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
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

    func testRejectsClass() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCViewModel
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
                DiagnosticSpec(message: "@MCViewModel can only be applied to a struct", line: 1, column: 1),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - @MCView Tests

final class MCViewMacroTests: XCTestCase {

    func testGeneratesDataProperty() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCView(HomeViewModel.self)
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

                @HomeViewModel._HomeViewModelProvider var data
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
            @MCView(HomeViewModel.self)
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
