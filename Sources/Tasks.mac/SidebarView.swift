import SwiftUI

struct SidebarView: View {
    var body: some View {
        NavigationView {
            List {
                Text("Local")
                    .font(.system(size: 10))
                    .fontWeight(.bold)
            }
        }
    }
}
