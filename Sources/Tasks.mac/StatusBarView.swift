import SwiftUI

enum ServerType {
    case generic
    case nextcloud
}

struct StatusBarView: View {
    @ObservedObject var store: TaskStore
    @State private var isEditingServer = false

    private var lastSyncText: String {
        guard let lastSync = store.lastSync else { return "Last sync: Never" }
        return "Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
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
                .accessibilityIdentifier("syncButton")
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
            ServerEditView(
                initialType: store.nextcloudServerURL != nil ? .nextcloud : .generic,
                initialGenericURL: store.serverAddress ?? "",
                initialNextcloudServerURL: store.nextcloudServerURL ?? "",
                initialNextcloudUsername: store.nextcloudUsername ?? ""
            ) { store.updateServerConfiguration($0) }
        }
    }
}

struct ServerEditView: View {
    @State private var serverType: ServerType
    @State private var genericURL: String
    @State private var nextcloudServerURL: String
    @State private var nextcloudUsername: String
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (ServerConfiguration) -> Void

    init(
        initialType: ServerType = .generic,
        initialGenericURL: String = "",
        initialNextcloudServerURL: String = "",
        initialNextcloudUsername: String = "",
        onConfirm: @escaping (ServerConfiguration) -> Void
    ) {
        _serverType = State(initialValue: initialType)
        _genericURL = State(initialValue: initialGenericURL)
        _nextcloudServerURL = State(initialValue: initialNextcloudServerURL)
        _nextcloudUsername = State(initialValue: initialNextcloudUsername)
        self.onConfirm = onConfirm
    }

    private var isValid: Bool {
        switch serverType {
        case .generic:
            return isValidCalDAVURL(genericURL)
        case .nextcloud:
            return isValidCalDAVURL(nextcloudServerURL)
                && !nextcloudUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("CalDAV Server")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Generic CalDAV") { serverType = .generic }
                    .accessibilityIdentifier("genericServerType")
                Button("Nextcloud") { serverType = .nextcloud }
                    .accessibilityIdentifier("nextcloudServerType")
            }

            // Both field groups are always rendered so the NSTextField backing and
            // SwiftUI binding coordinator are established on the first draw. Using
            // if/else here would create the NSTextField only after the mode switch,
            // leaving the AX binding delegate unhooked at interaction time.
            VStack(alignment: .leading, spacing: 4) {
                TextField("https://example.com/dav", text: $genericURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                if !genericURL.isEmpty && !isValidCalDAVURL(genericURL) && serverType == .generic {
                    Text("Enter a valid http:// or https:// URL")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .opacity(serverType == .generic ? 1 : 0)
            .frame(height: serverType == .generic ? nil : 0)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                TextField("https://cloud.example.com", text: $nextcloudServerURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .accessibilityIdentifier("nextcloudServerURLField")
                TextField("Username", text: $nextcloudUsername)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .accessibilityIdentifier("nextcloudUsernameField")
            }
            .opacity(serverType == .nextcloud ? 1 : 0)
            .frame(height: serverType == .nextcloud ? nil : 0)
            .clipped()

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Connect") {
                    switch serverType {
                    case .generic:
                        onConfirm(.generic(url: genericURL))
                    case .nextcloud:
                        onConfirm(.nextcloud(serverURL: nextcloudServerURL, username: nextcloudUsername))
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .accessibilityIdentifier("connectButton")
            }
        }
        .padding(24)
    }
}
