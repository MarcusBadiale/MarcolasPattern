//
//  MarcolasPattern.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - @MCProvider
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Separates logic from UI using a generated DynamicProperty provider.
///
/// The developer writes a plain struct with @Query, @State, @Environment,
/// computed properties, and functions. The macro generates:
///
/// 1. **`<Name>Data`** — a struct with lets, @Bindings, and closures
/// 2. **`_<Name>Provider`** — a `@propertyWrapper` conforming to `DynamicProperty`
///    that holds all the property wrappers and exposes Data as its `wrappedValue`.
///    SwiftUI automatically tracks @Query/@State/@Environment changes.
///
/// ```swift
/// @MCProvider
/// struct HomeProvider {
///     @Query(sort: \Recipe.name) var recipes: [Recipe]
///     @State var searchText: String = ""
///     @Environment(\.modelContext) var modelContext
///
///     var filteredRecipes: [Recipe] { ... }
///     func deleteRecipe(_ recipe: Recipe) { ... }
/// }
/// ```
@attached(member, names: arbitrary)
public macro MCProvider() = #externalMacro(
    module: "MarcolasPatternMacros",
    type: "MCProviderMacro"
)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - @MCView
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Injects a `data` property backed by the Provider's DynamicProperty provider.
///
/// The developer writes `body` normally and accesses `data` to get the Provider's
/// Data struct. No Bridge View, no `ui(data:)` function needed.
///
/// The macro generates both the `data` property and a default `init()`.
/// If the Provider has no dependencies, zero boilerplate is needed:
///
/// ```swift
/// @MCView(HomeProvider.self)
/// struct HomeView: View {
///     var body: some View {
///         List(data.filteredRecipes) { recipe in
///             Text(recipe.name)
///         }
///         .searchable(text: data.$searchText)
///     }
/// }
/// ```
///
/// If the Provider has dependencies (e.g. `let habitID: UUID`), the generated
/// `init()` won't compile — the compiler will tell you exactly which parameters
/// are missing. In that case, write your own init and the macro will skip generation:
///
/// ```swift
/// @MCView(HabitDetailProvider.self)
/// struct HabitDetailView: View {
///     init(habitID: UUID) {
///         self._data = .init(habitID: habitID)
///     }
///
///     var body: some View { ... }
/// }
/// ```
@attached(member, names: named(data), named(init))
public macro MCView<T>(_ viewModel: T.Type) = #externalMacro(
    module: "MarcolasPatternMacros",
    type: "MCViewMacro"
)
