import MarcolasPattern
import SwiftUI

@MCProvider
struct TodoListProvider {
    @State var todos: [Todo] = []
    @State var isLoading: Bool = false
    @State var errorMessage: String? = nil
    @State var newTodoTitle: String = ""

    let repository = TodoRepository()

    var pending: [Todo] { todos.filter { !$0.isDone } }
    var done: [Todo] { todos.filter { $0.isDone } }
    var pendingCount: Int { pending.count }

    func loadTodos() async {
        isLoading = true
        errorMessage = nil
        do {
            todos = try await repository.fetchTodos()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addTodo() {
        guard !newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        todos.append(Todo(title: newTodoTitle))
        newTodoTitle = ""
    }

    func toggle(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isDone.toggle()
    }

    func delete(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
    }
}
