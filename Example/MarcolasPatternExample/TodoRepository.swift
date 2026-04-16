import Foundation

class TodoRepository {
    func fetchTodos() async throws -> [Todo] {
        try await Task.sleep(for: .seconds(1))
        return [
            Todo(title: "Buy groceries"),
            Todo(title: "Walk the dog"),
            Todo(title: "Read a book", isDone: true),
            Todo(title: "Write some Swift"),
        ]
    }
}
