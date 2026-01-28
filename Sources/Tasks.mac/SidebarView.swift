import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Section("Quick Access") {
                Text("Today")
                Text("Scheduled")
            }
            
            Section("Lists") {
                Text("All")
                Text("Completed")
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

