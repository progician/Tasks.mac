import Foundation

public struct Task: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public var isCompleted: Bool = false

    public init(title: String, id: UUID = UUID()) {
        self.id = id
        self.title = title
    }

    public static func == (lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }
}
