import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published var calendars: [CalDAVCalendar] = []
    @Published var tasks: [Task] = []
    @Published var selectedCalendar: CalDAVCalendar?
    @Published var syncError: String?
    @Published var lastSync: Date?
    @Published var hasLocalChanges: Bool = false
    @Published var serverAddress: String?

    private var client: CalDAVClient?
    private let storage: ServerAddressStorage

    init() {
        let domain = ProcessInfo.processInfo.environment["AT_DEFAULTS_DOMAIN"]
        let defaults = domain.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        storage = ServerAddressStorage(defaults: defaults)

        let rawURL = ProcessInfo.processInfo.environment["CALDAV_URL"] ?? storage.load()
        serverAddress = rawURL
        if let rawURL, let url = URL(string: rawURL) {
            client = CalDAVClient(baseURL: url)
        }
    }

    func updateServerAddress(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        serverAddress = trimmed.isEmpty ? nil : trimmed
        if let address = serverAddress, let url = URL(string: address) {
            storage.save(address)
            client = CalDAVClient(baseURL: url)
        } else {
            storage.clear()
            client = nil
        }
    }

    func sync() async {
        guard let client else { return }
        syncError = nil
        do {
            let discovered = try await client.discoverCalendars()
            calendars = discovered
            if let first = discovered.first {
                selectedCalendar = first
                tasks = try await client.fetchTasks(from: first.id)
                    .map { Task(title: $0.summary) }
            }
            lastSync = Date()
        } catch CalDAVError.authenticationRequired {
            syncError = "CalDAV server requires authentication"
        } catch {
            // Surface errors properly in a later iteration.
        }
    }
}
