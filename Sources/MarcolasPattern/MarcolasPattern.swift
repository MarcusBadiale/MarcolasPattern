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

/// Separates logic from UI using a generated Bridge View.
///
/// The developer writes a plain struct with @Query, @State, @Environment,
/// computed properties, and functions. The macro generates:
///
/// 1. **`<Name>Data`** — a struct with lets, @Bindings, and closures
/// 2. **`_<Name>Bridge<Content: View>`** — a generic View that holds all
///    the property wrappers (so @Query works) and renders the Content
///    closure with the Data. Zero AnyView — the concrete type flows through.
/// 3. **`currentData`** — computed property that packs everything into Data
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

/// Generates View conformance that wires the Bridge to the developer's `ui` function.
///
/// ```swift
/// @MCView(HomeViewModel.self)
/// struct HomeView {
///     @ViewBuilder
///     func ui(data: HomeViewModelData) -> some View {
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
/// extension HomeView: View {
///     var body: some View {
///         _HomeViewModelBridge { data in
///             ui(data: data)
///         }
///     }
/// }
/// ```
@attached(extension, conformances: View, names: arbitrary)
public macro MCView<T>(_ viewModel: T.Type) = #externalMacro(
    module: "MarcolasPatternMacros",
    type: "MCViewMacro"
)
