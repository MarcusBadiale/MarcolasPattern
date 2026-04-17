//
//  MarcolasPattern.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - @MCViewModel
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
/// @MCViewModel
/// struct HomeViewModel {
///     @Query(sort: \Recipe.name) var recipes: [Recipe]
///     @State var searchText: String = ""
///     @Environment(\.modelContext) var modelContext
///
///     var filteredRecipes: [Recipe] { ... }
///     func deleteRecipe(_ recipe: Recipe) { ... }
/// }
/// ```
@attached(member, names: arbitrary)
public macro MCViewModel() = #externalMacro(
    module: "MarcolasPatternMacros",
    type: "MCViewModelMacro"
)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - @MCView
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Injects a `data` property backed by the ViewModel's DynamicProperty provider.
///
/// The developer writes `body` normally and accesses `data` to get the ViewModel's
/// Data struct. No Bridge View, no `ui(data:)` function needed.
///
/// ```swift
/// @MCView(HomeViewModel.self)
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
/// Generates:
/// ```swift
/// @HomeViewModel._HomeViewModelProvider var data
/// ```
@attached(member, names: named(data))
public macro MCView<T>(_ viewModel: T.Type) = #externalMacro(
    module: "MarcolasPatternMacros",
    type: "MCViewMacro"
)
