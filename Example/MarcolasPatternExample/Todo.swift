import Foundation

struct Todo: Identifiable {
    let id = UUID()
    var title: String
    var isDone: Bool = false
}
