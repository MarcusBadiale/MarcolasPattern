import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MarcolasPatternMacros)
import MarcolasPatternMacros
#endif

// MARK: - @MCProvider Property Tests

final class MCProviderTests: XCTestCase {

    func testGeneratesDataStructAndProvider() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct HomeProvider {
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
            struct HomeProvider {
                @Query var items: [Item]
                @State var searchText: String = ""
                @Environment(\\.modelContext) var modelContext

                var filteredItems: [Item] {
                    items.filter { $0.name.contains(searchText) }
                }

                func deleteItem(_ item: Item) {
                    modelContext.delete(item)
                }

                /// Auto-generated data for `HomeProvider`.
                public struct HomeData: CustomDebugStringConvertible {
                    public let items: [Item]
                    @Binding public var searchText: String
                    public let filteredItems: [Item]
                    public let deleteItem: (Item) -> Void
                    public var debugDescription: String {
                        "HomeData(items: \\(items), searchText: \\(searchText), filteredItems: \\(filteredItems), deleteItem: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
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

                    var wrappedValue: HomeData {
                        HomeData(
                            items: items,
                            searchText: $searchText,
                            filteredItems: filteredItems,
                            deleteItem: { [self] item in
                                self.deleteItem(item)
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var items: [Item]

                    var searchText: String

                    var filteredItems: [Item] {
                        items.filter {
                            $0.name.contains(searchText)
                        }
                    }

                    mutating func deleteItem(_ item: Item) {
                        modelContext.delete(item)
                    }

                    init(items: [Item], searchText: String = "") {
                        self.items = items
                        self.searchText = searchText
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
            @MCProvider
            struct SettingsProvider {
                @State var isDarkMode: Bool = false
                @State var fontSize: Double = 14.0
            }
            """,
            expandedSource: """
            struct SettingsProvider {
                @State var isDarkMode: Bool = false
                @State var fontSize: Double = 14.0

                /// Auto-generated data for `SettingsProvider`.
                public struct SettingsData: CustomDebugStringConvertible {
                    @Binding public var isDarkMode: Bool
                    @Binding public var fontSize: Double
                    public var debugDescription: String {
                        "SettingsData(isDarkMode: \\(isDarkMode), fontSize: \\(fontSize))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @State var isDarkMode: Bool = false

                    @State var fontSize: Double = 14.0

                    var wrappedValue: SettingsData {
                        SettingsData(
                            isDarkMode: $isDarkMode,
                            fontSize: $fontSize
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var isDarkMode: Bool

                    var fontSize: Double

                    init(isDarkMode: Bool = false, fontSize: Double = 14.0) {
                        self.isDarkMode = isDarkMode
                        self.fontSize = fontSize
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

    func testBindableProperty() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct ItemDetailProvider {
                @Bindable var item: Item

                func save() {
                    item.name = "Updated"
                }
            }
            """,
            expandedSource: """
            struct ItemDetailProvider {
                @Bindable var item: Item

                func save() {
                    item.name = "Updated"
                }

                /// Auto-generated data for `ItemDetailProvider`.
                public struct ItemDetailData: CustomDebugStringConvertible {
                    @Bindable public var item: Item
                    public let save: () -> Void
                    public var debugDescription: String {
                        "ItemDetailData(item: \\(item), save: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @Bindable var item: Item

                    func save() {
                        item.name = "Updated"
                    }

                    var wrappedValue: ItemDetailData {
                        ItemDetailData(
                            item: item,
                            save: { [self] in
                                self.save()
                            }
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var item: Item

                    mutating func save() {
                        item.name = "Updated"
                    }

                    init(item: Item) {
                        self.item = item
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
            @MCProvider
            struct HomeProvider {
                let repository: TodoRepository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }
            }
            """,
            expandedSource: """
            struct HomeProvider {
                let repository: TodoRepository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }

                /// Auto-generated data for `HomeProvider`.
                public struct HomeData: CustomDebugStringConvertible {
                    public let repository: TodoRepository
                    public let load: @Sendable () async -> Void
                    public var debugDescription: String {
                        "HomeData(repository: \\(repository), load: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let repository: TodoRepository

                    func load() async {
                        await repository.fetch()
                    }

                    init(repository: TodoRepository = TodoRepository()) {
                        self.repository = repository
                    }

                    var wrappedValue: HomeData {
                        HomeData(
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

                struct Mock {
                    var repository: TodoRepository

                    mutating func load() async {
                        await repository.fetch()
                    }

                    init(repository: TodoRepository) {
                        self.repository = repository
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
            @MCProvider
            struct HomeProvider {
                let repository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }
            }
            """,
            expandedSource: """
            struct HomeProvider {
                let repository = TodoRepository()

                func load() async {
                    await repository.fetch()
                }

                /// Auto-generated data for `HomeProvider`.
                public struct HomeData: CustomDebugStringConvertible {
                    public let repository: TodoRepository
                    public let load: @Sendable () async -> Void
                    public var debugDescription: String {
                        "HomeData(repository: \\(repository), load: (closure))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let repository: TodoRepository

                    func load() async {
                        await repository.fetch()
                    }

                    init(repository: TodoRepository = TodoRepository()) {
                        self.repository = repository
                    }

                    var wrappedValue: HomeData {
                        HomeData(
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

                struct Mock {
                    var repository: TodoRepository

                    mutating func load() async {
                        await repository.fetch()
                    }

                    init(repository: TodoRepository) {
                        self.repository = repository
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

    func testDependencyInjectionWithRequiredAndOptionalParams() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct DetailProvider {
                let itemID: UUID
                let repository: ItemRepository = ItemRepository()
            }
            """,
            expandedSource: """
            struct DetailProvider {
                let itemID: UUID
                let repository: ItemRepository = ItemRepository()

                /// Auto-generated data for `DetailProvider`.
                public struct DetailData: CustomDebugStringConvertible {
                    public let itemID: UUID
                    public let repository: ItemRepository
                    public var debugDescription: String {
                        "DetailData(itemID: \\(itemID), repository: \\(repository))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    let itemID: UUID

                    let repository: ItemRepository

                    init(itemID: UUID, repository: ItemRepository = ItemRepository()) {
                        self.itemID = itemID
                        self.repository = repository
                    }

                    var wrappedValue: DetailData {
                        DetailData(
                            itemID: itemID,
                            repository: repository
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var itemID: UUID

                    var repository: ItemRepository

                    init(itemID: UUID, repository: ItemRepository) {
                        self.itemID = itemID
                        self.repository = repository
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

    func testMultipleEnvironments() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct ListProvider {
                @Environment(\\.modelContext) var modelContext
                @Environment(\\.dismiss) var dismiss
            }
            """,
            expandedSource: """
            struct ListProvider {
                @Environment(\\.modelContext) var modelContext
                @Environment(\\.dismiss) var dismiss

                /// Auto-generated data for `ListProvider`.
                public struct ListData: CustomDebugStringConvertible {

                    public var debugDescription: String {
                        "ListData()"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    @Environment(\\.modelContext) var modelContext

                    @Environment(\\.dismiss) var dismiss

                    var wrappedValue: ListData {
                        ListData(

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
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEmptyProvider() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct EmptyProvider {
            }
            """,
            expandedSource: """
            struct EmptyProvider {

                /// Auto-generated data for `EmptyProvider`.
                public struct EmptyData: CustomDebugStringConvertible {

                    public var debugDescription: String {
                        "EmptyData()"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    var wrappedValue: EmptyData {
                        EmptyData(

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
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testOnlyComputedProperties() throws {
        #if canImport(MarcolasPatternMacros)
        assertMacroExpansion(
            """
            @MCProvider
            struct StatsProvider {
                var total: Int {
                    42
                }
                var label: String {
                    "Total: \\(total)"
                }
            }
            """,
            expandedSource: """
            struct StatsProvider {
                var total: Int {
                    42
                }
                var label: String {
                    "Total: \\(total)"
                }

                /// Auto-generated data for `StatsProvider`.
                public struct StatsData: CustomDebugStringConvertible {
                    public let total: Int
                    public let label: String
                    public var debugDescription: String {
                        "StatsData(total: \\(total), label: \\(label))"
                    }
                }

                @MainActor @propertyWrapper
                struct _DataWrapper: DynamicProperty {
                    var total: Int {
                        42
                    }

                    var label: String {
                        "Total: \\(total)"
                    }

                    var wrappedValue: StatsData {
                        StatsData(
                            total: total,
                            label: label
                        )
                    }

                    var projectedValue: Self {
                        self
                    }
                }

                struct Mock {
                    var total: Int {
                        42
                    }

                    var label: String {
                        "Total: \\(total)"
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
