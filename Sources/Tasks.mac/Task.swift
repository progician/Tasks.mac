import Foundation

struct Task: Identifiable, Equatable {
    let id: UUID
    let title: String
    var isCompleted: Bool = false

    init(title: String, id: UUID = UUID()) {
        self.id = id
        self.title = title
    }

    static func == (lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }
}
