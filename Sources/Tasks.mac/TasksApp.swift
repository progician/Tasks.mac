import SwiftUI

@main
struct TasksApp: App {
    var body: some Scene {
        WindowGroup {
            SidebarView()
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            HStack {
                Text("[01] This Week")
                Text("12")
            }
            HStack {
                Text("277 Completed")
                Text("·")
                Text("Show")
            }
            Divider()
        }
        .padding()
    }
}
