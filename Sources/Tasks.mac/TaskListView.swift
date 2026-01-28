import SwiftUI

struct TaskListView: View {
    @State var tasks: [Task] = [
        Task(title: "Check in on buying the house on Hengrove"),
        Task(title: "Schedule a chat with Barbi about budget"),
        Task(title: "Do a full sweep of the missing budget tracking"),
        Task(title: "Consolidate budget tracking"),
        Task(title: "Eye of Jupiter for Viktor's birthday"),
        Task(title: "Automate categorization of spending entries"),
        Task(title: "Look up SBX exercise routine"),
        Task(title: "Log carbot renewal into Loki"),
        Task(title: "Choose chat apps to use"),
        Task(title: "Download: Under the salt marsh"),
        Task(title: "Buy render filler"),
        Task(title: "Replace Julia's bike wheel inner tube"),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach($tasks) { $task in
                HStack(spacing: 12) {
                    Button(action: {
                        task.isCompleted.toggle()
                    }) {
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
