import SwiftUI

@main
struct TasksApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView()
            } detail: {
                ContentView()
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("[01] This Week")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("12")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            .padding()
            
            HStack {
                Text("277 Completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary)
                Text("Show")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Divider()
                .opacity(0.2)
            
            TaskListView()
            
            Spacer()
        }
    }
}
