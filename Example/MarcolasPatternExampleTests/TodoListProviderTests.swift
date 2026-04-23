import XCTest
@testable import MarcolasPatternExample

// MARK: - Mock Repository

class MockTodoRepository: TodoRepository {
    var mockTodos: [Todo] = []
    var shouldThrow = false
    var fetchCallCount = 0

    override func fetchTodos() async throws -> [Todo] {
        fetchCallCount += 1
        if shouldThrow {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return mockTodos
    }
}

// MARK: - Tests

final class TodoListProviderTests: XCTestCase {

    // MARK: - addTodo

    func testAddTodoAppendsAndClearsTitle() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.newTodoTitle = "Buy milk"

        sut.addTodo()

        XCTAssertEqual(sut.todos.count, 1)
        XCTAssertEqual(sut.todos[0].title, "Buy milk")
        XCTAssertFalse(sut.todos[0].isDone)
        XCTAssertEqual(sut.newTodoTitle, "")
    }

    func testAddTodoIgnoresEmptyTitle() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.newTodoTitle = ""

        sut.addTodo()

        XCTAssertTrue(sut.todos.isEmpty)
    }

    func testAddTodoIgnoresWhitespaceOnlyTitle() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.newTodoTitle = "   "

        sut.addTodo()

        XCTAssertTrue(sut.todos.isEmpty)
    }

    func testAddMultipleTodos() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())

        sut.newTodoTitle = "First"
        sut.addTodo()
        sut.newTodoTitle = "Second"
        sut.addTodo()

        XCTAssertEqual(sut.todos.count, 2)
        XCTAssertEqual(sut.todos[0].title, "First")
        XCTAssertEqual(sut.todos[1].title, "Second")
    }

    // MARK: - toggle

    func testToggleMarksTodoAsDone() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [Todo(title: "Task")]

        sut.toggle(sut.todos[0])

        XCTAssertTrue(sut.todos[0].isDone)
    }

    func testToggleMarksBackAsNotDone() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [Todo(title: "Task", isDone: true)]

        sut.toggle(sut.todos[0])

        XCTAssertFalse(sut.todos[0].isDone)
    }

    func testToggleIgnoresUnknownTodo() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [Todo(title: "Task")]
        let unknownTodo = Todo(title: "Unknown")

        sut.toggle(unknownTodo)

        XCTAssertFalse(sut.todos[0].isDone)
    }

    // MARK: - delete

    func testDeleteRemovesTodo() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        let todo = Todo(title: "To remove")
        sut.todos = [todo, Todo(title: "Keep")]

        sut.delete(todo)

        XCTAssertEqual(sut.todos.count, 1)
        XCTAssertEqual(sut.todos[0].title, "Keep")
    }

    func testDeleteIgnoresUnknownTodo() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [Todo(title: "Keep")]
        let unknownTodo = Todo(title: "Unknown")

        sut.delete(unknownTodo)

        XCTAssertEqual(sut.todos.count, 1)
    }

    // MARK: - Computed Properties

    func testPendingFiltersDoneTodos() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [
            Todo(title: "A", isDone: false),
            Todo(title: "B", isDone: true),
            Todo(title: "C", isDone: false),
        ]

        XCTAssertEqual(sut.pending.count, 2)
        XCTAssertEqual(sut.pending.map(\.title), ["A", "C"])
    }

    func testDoneFiltersPendingTodos() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [
            Todo(title: "A", isDone: false),
            Todo(title: "B", isDone: true),
            Todo(title: "C", isDone: true),
        ]

        XCTAssertEqual(sut.done.count, 2)
        XCTAssertEqual(sut.done.map(\.title), ["B", "C"])
    }

    func testPendingCountMatchesPending() {
        var sut = TodoListProvider.Mock(repository: MockTodoRepository())
        sut.todos = [
            Todo(title: "A", isDone: false),
            Todo(title: "B", isDone: true),
            Todo(title: "C", isDone: false),
        ]

        XCTAssertEqual(sut.pendingCount, 2)
    }

    // MARK: - loadTodos

    func testLoadTodosSuccess() async {
        let mockRepo = MockTodoRepository()
        mockRepo.mockTodos = [Todo(title: "From API")]
        var sut = TodoListProvider.Mock(repository: mockRepo)

        await sut.loadTodos()

        XCTAssertEqual(sut.todos.count, 1)
        XCTAssertEqual(sut.todos[0].title, "From API")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockRepo.fetchCallCount, 1)
    }

    func testLoadTodosError() async {
        let mockRepo = MockTodoRepository()
        mockRepo.shouldThrow = true
        var sut = TodoListProvider.Mock(repository: mockRepo)

        await sut.loadTodos()

        XCTAssertTrue(sut.todos.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.errorMessage, "Mock error")
    }

    func testLoadTodosClearsErrorOnRetry() async {
        let mockRepo = MockTodoRepository()
        mockRepo.shouldThrow = true
        var sut = TodoListProvider.Mock(repository: mockRepo)

        await sut.loadTodos()
        XCTAssertNotNil(sut.errorMessage)

        mockRepo.shouldThrow = false
        mockRepo.mockTodos = [Todo(title: "Recovered")]
        await sut.loadTodos()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.todos.count, 1)
    }
}
