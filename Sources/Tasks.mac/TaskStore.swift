import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published var calendars: [CalDAVCalendar] = []
    @Published var tasks: [Task] = []
    @Published var selectedCalendar: CalDAVCalendar?
    @Published var syncError: String?
    @Published var lastSync: Date?
    @Published var hasLocalChanges: Bool = false

    let serverAddress: String?
    private let client: CalDAVClient?

    init() {
        let rawURL = ProcessInfo.processInfo.environment["CALDAV_URL"]
        serverAddress = rawURL
        if let rawURL, let url = URL(string: rawURL) {
            client = CalDAVClient(baseURL: url)
        } else {
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
