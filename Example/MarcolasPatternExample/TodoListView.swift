import MarcolasPattern
import SwiftUI

@MCView(TodoListViewModel.self)
struct TodoListView {
    @ViewBuilder
    func ui(data: TodoListViewModel.TodoListViewModelData) -> some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New todo...", text: data.$newTodoTitle)
                            .onSubmit { data.addTodo() }
                        Button {
                            data.addTodo()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(data.newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if data.isLoading {
                    ProgressView("Loading...")
                }

                if let error = data.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                if !data.pending.isEmpty {
                    Section("Pending - \(data.pendingCount)") {
                        ForEach(data.pending) { todo in
                            TodoRow(todo: todo, onToggle: { data.toggle(todo) })
                        }
                    }
                }

                if !data.done.isEmpty {
                    Section("Done") {
                        ForEach(data.done) { todo in
                            TodoRow(todo: todo, onToggle: { data.toggle(todo) })
                        }
                    }
                }
            }
            .navigationTitle("Todos")
            .task { await data.loadTodos() }
        }
    }
}
