# MarcolasPattern

A Swift macro library that implements a clean architecture pattern for SwiftUI, separating business logic from UI through compile-time code generation.

## Overview

MarcolasPattern provides two macros — `@MCViewModel` and `@MCView` — that eliminate boilerplate while enforcing a clear separation of concerns. Write your ViewModel as a simple struct with property wrappers and methods, and the macros generate all the bridging code at compile time with zero runtime overhead.

**How it works:**

1. `@MCViewModel` analyzes your struct and generates:
   - A `Data` struct that packages all properties (as bindings where appropriate) and methods (as closures)
   - A `Bridge` view that holds the real property wrappers and renders your UI
2. `@MCView` wires your view's `ui(data:)` function to the generated Bridge

## Requirements

- Swift 6.0+
- macOS 15+ / iOS 18+

## Installation

Add MarcolasPattern to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/MarcusBadiale/MarcolasPattern.git", from: "1.0.0"),
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["MarcolasPattern"]
)
```

## Usage

### ViewModel

```swift
import MarcolasPattern

@MCViewModel
struct TodoListViewModel {
    @State var todos: [Todo] = []
    @State var isLoading: Bool = false
    @State var newTodoTitle: String = ""

    let repository = TodoRepository()

    var pending: [Todo] { todos.filter { !$0.isDone } }
    var done: [Todo] { todos.filter { $0.isDone } }

    func loadTodos() async {
        isLoading = true
        todos = try await repository.fetchTodos()
        isLoading = false
    }

    func addTodo() {
        guard !newTodoTitle.isEmpty else { return }
        todos.append(Todo(title: newTodoTitle))
        newTodoTitle = ""
    }
}
```

The macro generates a `TodoListViewModelData` struct with:
- `@Binding var todos: [Todo]` / `@Binding var isLoading: Bool` / `@Binding var newTodoTitle: String`
- `let repository: TodoRepository`
- `let pending: [Todo]` / `let done: [Todo]`
- `let loadTodos: () async -> Void` / `let addTodo: () -> Void`

### View

```swift
@MCView(TodoListViewModel.self)
struct TodoListView {
    @ViewBuilder
    func ui(data: TodoListViewModelData) -> some View {
        NavigationStack {
            List {
                TextField("New todo...", text: data.$newTodoTitle)
                    .onSubmit { data.addTodo() }

                if data.isLoading {
                    ProgressView("Loading...")
                }

                ForEach(data.pending) { todo in
                    Text(todo.title)
                }
            }
            .task { await data.loadTodos() }
        }
    }
}
```

### Supported Property Types

| Declaration | Generated in Data |
|---|---|
| `@State var name: T = ...` | `@Binding var name: T` |
| `@Query(...) var items: [T]` | `let items: [T]` |
| `@Environment(\.key) var key` | `let key: T` |
| `let value = Foo()` | `let value: Foo` |
| `var computed: T { ... }` | `let computed: T` |
| `func doSomething()` | `let doSomething: () -> Void` |
| `func fetch() async throws` | `let fetch: () async -> Void` |

## How It Works

The `@MCViewModel` macro generates two types at compile time:

1. **`<Name>Data`** — A flat struct that the view consumes. `@State` properties become `@Binding`, methods become closures, and everything else becomes `let` constants.

2. **`_<Name>Bridge<Content: View>`** — A private SwiftUI view that owns the real property wrappers (`@State`, `@Query`, `@Environment`) and passes a populated `Data` instance to your UI closure.

The `@MCView` macro generates a `View` conformance that connects your `ui(data:)` function to the Bridge:

```swift
extension TodoListView: View {
    var body: some View {
        TodoListViewModel._TodoListViewModelBridge { data in
            ui(data: data)
        }
    }
}
```

This gives you full type inference (no `AnyView`), testable ViewModels, and clean UI code.

## License

MIT
