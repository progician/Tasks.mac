import Foundation

struct Task: Identifiable, Equatable {
    let id = UUID()
    let title: String
    var isCompleted: Bool = false
    
    static func == (lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }
}
