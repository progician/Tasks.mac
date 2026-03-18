import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        List {
            Section("Quick Access") {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("5").font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Text("Scheduled")
                    Spacer()
                    Text("3").font(.caption).foregroundColor(.secondary)
                }
            }

            Section("Lists") {
                HStack {
                    Text("All")
                    Spacer()
                    Text("44").font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Text("Completed")
                    Spacer()
                    Text("277").font(.caption).foregroundColor(.secondary)
                }
            }

            if !store.calendars.isEmpty {
                Section("My Lists") {
                    ForEach(store.calendars) { calendar in
                        Text(calendar.displayName)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
