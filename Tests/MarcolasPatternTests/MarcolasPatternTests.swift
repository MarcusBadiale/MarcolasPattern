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

    func testGeneratesDataStructAndBridge() throws {
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
                    public let deleteItem: (Item) -> Void
                }

                struct _HomeViewModelBridge<Content: View>: View {
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

                    let content: (HomeViewModelData) -> Content

                    private var currentData: HomeViewModelData {
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

                    var body: some View {
                        content(currentData)
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

                struct _SettingsViewModelBridge<Content: View>: View {
                    @State var isDarkMode: Bool = false

                    @State var fontSize: Double = 14.0

                    let content: (SettingsViewModelData) -> Content

                    private var currentData: SettingsViewModelData {
                        SettingsViewModelData(
                            isDarkMode: $isDarkMode,
                            fontSize: $fontSize
                        )
                    }

                    var body: some View {
                        content(currentData)
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
                    public let updateItem: (Item, String) -> Void
                }

                struct _EditorViewModelBridge<Content: View>: View {
                    func updateItem(_ item: Item, newName: String) {
                        item.name = newName
                    }

                    let content: (EditorViewModelData) -> Content

                    private var currentData: EditorViewModelData {
                        EditorViewModelData(
                            updateItem: { [self] item, newName in
                                MainActor.assumeIsolated {
                                    self.updateItem(item, newName: newName)
                                }
                            }
                        )
                    }

                    var body: some View {
                        content(currentData)
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
                    public let loadItems: () async -> Void
                }

                struct _FeedViewModelBridge<Content: View>: View {
                    @State var items: [String] = []

                    @State var isLoading: Bool = false

                    func loadItems() async {
                        isLoading = true
                        items = await fetchItems()
                        isLoading = false
                    }

                    let content: (FeedViewModelData) -> Content

                    private var currentData: FeedViewModelData {
                        FeedViewModelData(
                            items: $items,
                            isLoading: $isLoading,
                            loadItems: { [self] in
                                await self.loadItems()
                            }
                        )
                    }

                    var body: some View {
                        content(currentData)
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
                    public let load: () async -> Void
                }

                struct _HomeViewModelBridge<Content: View>: View {
                    let repository: TodoRepository = TodoRepository()

                    func load() async {
                        await repository.fetch()
                    }

                    let content: (HomeViewModelData) -> Content

                    private var currentData: HomeViewModelData {
                        HomeViewModelData(
                            repository: repository,
                            load: { [self] in
                                await self.load()
                            }
                        )
                    }

                    var body: some View {
                        content(currentData)
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
                    public let load: () async -> Void
                }

                struct _HomeViewModelBridge<Content: View>: View {
                    let repository = TodoRepository()

                    func load() async {
                        await repository.fetch()
                    }

                    let content: (HomeViewModelData) -> Content

                    private var currentData: HomeViewModelData {
                        HomeViewModelData(
                            repository: repository,
                            load: { [self] in
                                await self.load()
                            }
                        )
                    }

                    var body: some View {
                        content(currentData)
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

    func testGeneratesBodyWithBridge() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCView(HomeViewModel.self)
            struct HomeView {
                @ViewBuilder
                func ui(data: HomeViewModelData) -> some View {
                    Text("Hello")
                }
            }
            """,
            expandedSource: """
            struct HomeView {
                @ViewBuilder
                func ui(data: HomeViewModelData) -> some View {
                    Text("Hello")
                }
            }

            extension HomeView: View {
                var body: some View {
                    HomeViewModel._HomeViewModelBridge { data in
                        ui(data: data)
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
