import SwiftUI

struct TaskListView: View {
    @Binding var tasks: [Task]

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
