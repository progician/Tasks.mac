import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: TaskStore

    private var lastSyncText: String {
        guard let lastSync = store.lastSync else { return "Last sync: Never" }
        return "Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        HStack(spacing: 12) {
            if let address = store.serverAddress {
                Text(address)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("CalDAV server not specified")
                    .foregroundStyle(.red)
            }
            Spacer()
            if store.hasLocalChanges {
                Text("Unsynced changes")
                    .foregroundStyle(.orange)
            }
            Text(lastSyncText)
            Button("Sync") { }
                .controlSize(.small)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("syncStatusBar")
    }
}
