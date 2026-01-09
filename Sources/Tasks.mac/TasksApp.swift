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
            Text("Hello, World!")
        }
        .padding()
    }
}
