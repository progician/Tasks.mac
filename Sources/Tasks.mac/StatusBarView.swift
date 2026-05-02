import SwiftUI

struct StatusBarView: View {
    @ObservedObject var store: TaskStore
    @State private var isEditingServer = false
    @State private var serverInput = ""

    private var lastSyncText: String {
        guard let lastSync = store.lastSync else { return "Last sync: Never" }
        return "Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                serverInput = store.serverAddress ?? ""
                isEditingServer = true
            } label: {
                if let address = store.serverAddress {
                    Text(address)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("CalDAV server not specified")
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.serverAddress ?? "CalDAV server not specified")
            .accessibilityIdentifier("serverAddressButton")

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
        .sheet(isPresented: $isEditingServer) {
            ServerEditView(serverInput: $serverInput) { store.updateServerAddress($0) }
        }
    }
}

struct ServerEditView: View {
    @Binding var serverInput: String
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (String) -> Void

    private var urlIsValid: Bool { isValidCalDAVURL(serverInput) }

    var body: some View {
        VStack(spacing: 20) {
            Text("CalDAV Server")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                TextField("https://example.com/dav", text: $serverInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                if !serverInput.isEmpty && !urlIsValid {
                    Text("Enter a valid http:// or https:// URL")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Connect") {
                    onConfirm(serverInput)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!urlIsValid)
                .accessibilityIdentifier("connectButton")
            }
        }
        .padding(24)
    }
}
