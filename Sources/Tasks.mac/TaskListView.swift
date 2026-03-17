import SwiftUI

struct TaskListView: View {
    @State var tasks: [Task] = [
        Task(title: "Organize emails"),
        Task(title: "Prepare a to-do list for the week"),
        Task(title: "Update personal budget spreadsheet"),
        Task(title: "Clean out the fridge"),
        Task(title: "Reply to pending messages or emails"),
        Task(title: "Plan meals for the week"),
        Task(title: "Review and update your resume"),
        Task(title: "Research new hobbies or interests"),
        Task(title: "Tidy up your workspace"),
        Task(title: "Pay bills or set up automatic payments"),
        Task(title: "Schedule doctor’s appointments or other necessary meetings"),
        Task(title: "Declutter one area of your home (e.g., closet, desk, or drawers)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($tasks) { $task in
                HStack(spacing: 12) {
                    Button {
                        task.isCompleted.toggle()
                    } label: {
                        Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .contentShape(Rectangle())

                if task != tasks.last {
                    Divider()
                        .opacity(0.2)
                }
            }
        }
    }
}

#Preview {
    TaskListView()
}
