# MarcolasPattern

A Swift macro library that implements a clean architecture pattern for SwiftUI, separating business logic from UI through compile-time code generation. Zero runtime overhead.

## Overview

MarcolasPattern provides two macros — `@MCProvider` and `@MCView` — that eliminate boilerplate while enforcing a clear separation of concerns. Write your Provider as a simple struct with property wrappers and methods, and the macros generate all the bridging code at compile time.

**What `@MCProvider` generates:**

1. **`Data` struct** — packages all properties (as bindings where appropriate) and methods (as closures) for the View to consume
2. **`_DataWrapper`** — a `@propertyWrapper` conforming to `DynamicProperty` that holds the real SwiftUI property wrappers and exposes Data as its `wrappedValue`
3. **`Mock` struct** — a plain Swift struct mirroring the Provider's logic, enabling unit testing without SwiftUI

**What `@MCView` generates:**

A `data` property backed by the Provider's `_DataWrapper`, giving the View access to the Data struct.

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

### Provider

```swift
import MarcolasPattern

@MCProvider
struct TodoListProvider {
    @State var todos: [Todo] = []
    @State var isLoading: Bool = false
    @State var newTodoTitle: String = ""

    let repository = TodoRepository()

    var pending: [Todo] { todos.filter { !$0.isDone } }
    var done: [Todo] { todos.filter { $0.isDone } }

    func loadTodos() async throws {
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

The macro generates a `TodoListData` struct with:
- `@Binding var todos: [Todo]` / `@Binding var isLoading: Bool` / `@Binding var newTodoTitle: String`
- `let repository: TodoRepository`
- `let pending: [Todo]` / `let done: [Todo]`
- `let loadTodos: @Sendable () async throws -> Void` / `let addTodo: @Sendable () -> Void`

### View

```swift
@MCView(TodoListProvider.self)
struct TodoListView: View {
    var body: some View {
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
            .task { try? await data.loadTodos() }
        }
    }
}
```

### Passing Parameters to the Provider

When your Provider needs external data (like an ID), use the `_data` property to initialize it:

```swift
@MCProvider
struct HabitDetailProvider {
    let habitID: UUID
    let repository = HabitRepository()
    @State var habit: Habit? = nil

    func load() async {
        habit = await repository.fetch(habitID)
    }
}

@MCView(HabitDetailProvider.self)
struct HabitDetailView: View {
    init(habitID: UUID) {
        self._data = .init(habitID: habitID)
    }

    var body: some View {
        // ...
    }
}
```

### Supported Property Types

| Declaration | Generated in Data | Generated in Mock |
|---|---|---|
| `@State var name: T = ...` | `@Binding var name: T` | `var name: T` (keeps default) |
| `@Query(...) var items: [T]` | `let items: [T]` | `var items: T` (required) |
| `@Environment(\.key) var key: T` | _(excluded)_ | `var key: T` (required) |
| `@Bindable var item: T` | `@Bindable var item: T` | `var item: T` (required) |
| `let value = Foo()` | `let value: Foo` | `var value: Foo` (required) |
| `let value: T` | `let value: T` | `var value: T` (required) |
| `var computed: T { ... }` | `let computed: T` | Copied as-is |
| `func doSomething()` | `let doSomething: @Sendable () -> Void` | `mutating func` |
| `func fetch() async throws` | `let fetch: @Sendable () async throws -> Void` | `mutating func` |
| `let x = 30` | `let x: Int` _(inferred)_ | `var x: Int` (required) |
| `let x = "hello"` | `let x: String` _(inferred)_ | `var x: String` (required) |

### Type Inference

The macro infers types from common literal patterns:

| Pattern | Inferred Type |
|---|---|
| `let x = 30` | `Int` |
| `let x = 0.3` | `Double` |
| `let x = "text"` | `String` |
| `let x = true` | `Bool` |
| `let x = Foo()` | `Foo` |
| `let x = Foo.shared` | `Foo` |

If the type can't be inferred, the macro emits a warning at compile time.

## How It Works

The `@MCProvider` macro generates three types at compile time:

### 1. Data Struct

A flat struct the View consumes. `@State` properties become `@Binding`, methods become `@Sendable` closures, and everything else becomes `let` constants. Conforms to `CustomDebugStringConvertible` for easy debugging.

### 2. _DataWrapper

A `@MainActor @propertyWrapper` conforming to `DynamicProperty`. It holds the real SwiftUI property wrappers (`@State`, `@Query`, `@Environment`, `@Bindable`) and exposes a populated Data instance as its `wrappedValue`. SwiftUI automatically tracks changes through the `DynamicProperty` protocol.

The `@MainActor` annotation provides **compile-time thread safety** — the compiler prevents calling Provider functions from a non-main thread, unlike `MainActor.assumeIsolated` which would crash at runtime.

Regular properties (`let`) get an auto-generated `init` with defaults, enabling **dependency injection**:

```swift
// Default usage (uses real dependencies):
@MCView(TodoListProvider.self)
struct TodoListView: View { ... }

// Injecting a mock for previews:
self._data = .init(repository: MockRepository())
```

### 3. Mock Struct

A plain Swift struct that mirrors the Provider's properties and functions, but without SwiftUI property wrappers. This enables **unit testing** the Provider's business logic directly:

```swift
func testAddTodo() {
    var sut = TodoListProvider.Mock(repository: MockRepository())
    sut.newTodoTitle = "Buy milk"
    sut.addTodo()
    XCTAssertEqual(sut.todos.count, 1)
    XCTAssertEqual(sut.todos[0].title, "Buy milk")
    XCTAssertEqual(sut.newTodoTitle, "")
}
```

**Mock init rules:**
- `@State` properties keep their defaults (they're UI state)
- `@Query`, `@Bindable`, `@Environment`, and regular properties are **required** (they're dependencies)
- Functions become `mutating func`

## Architecture

```
┌─────────────────────────────────────────────┐
│  @MCProvider struct TodoListProvider        │
│  (Developer writes this)                    │
│                                             │
│  @State var todos: [Todo] = []              │
│  let repository = TodoRepository()          │
│  func addTodo() { ... }                     │
└──────────────┬──────────────────────────────┘
               │ Macro expansion (compile-time)
               ▼
┌──────────────────────┐  ┌───────────────────┐  ┌──────────────┐
│  TodoListData        │  │  _DataWrapper      │  │  Mock        │
│  (View consumes)     │  │  (DynamicProperty) │  │  (Testing)   │
│                      │  │                    │  │              │
│  @Binding var todos  │  │  @State var todos  │  │  var todos   │
│  let repository      │  │  let repository    │  │  var repo    │
│  let addTodo: ...    │  │  func addTodo()    │  │  mutating    │
└──────────────────────┘  └───────────────────┘  │  func add()  │
                                                  └──────────────┘
```

## License

MIT
