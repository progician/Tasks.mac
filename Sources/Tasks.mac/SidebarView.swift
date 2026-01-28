import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Section("Quick Access") {
                HStack {
                    Text("Today")
                    Spacer()
                    Text("5").font(.caption).foregroundColor(.gray)
                }
                HStack {
                    Text("Scheduled")
                    Spacer()
                    Text("3").font(.caption).foregroundColor(.gray)
                }
            }
            
            Section("Lists") {
                HStack {
                    Text("All")
                    Spacer()
                    Text("44").font(.caption).foregroundColor(.gray)
                }
                HStack {
                    Text("Completed")
                    Spacer()
                    Text("277").font(.caption).foregroundColor(.gray)
                }
            }
            
            Section("My Lists") {
                Text("[01] This Week")
                Text("[02] Next Week")
                Text("[03] This Month")
                Text("[04] Next Mon...")
                Text("[05] Long term")
                Text("[06] Recurring")
                Text("[07] Shopping...")
            }
            
            Section("Other") {
                Text("Inbox")
                Text("Deck: Personal")
            }
        }
        .listStyle(.sidebar)
    }
}

