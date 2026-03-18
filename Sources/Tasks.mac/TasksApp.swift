import SwiftUI

@main
struct TasksApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(store: store)
            } detail: {
                ContentView(store: store)
            }
            .task {
                await store.sync()
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(store.selectedCalendar?.displayName ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(store.tasks.count)")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            .padding()

            Divider()
                .opacity(0.2)

            TaskListView(tasks: $store.tasks)

            Spacer()
        }
    }
}
