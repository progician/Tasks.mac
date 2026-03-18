import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published var calendars: [CalDAVCalendar] = []
    @Published var tasks: [Task] = []
    @Published var selectedCalendar: CalDAVCalendar?

    private let client: CalDAVClient?

    init() {
        if let rawURL = ProcessInfo.processInfo.environment["CALDAV_URL"],
           let url = URL(string: rawURL) {
            client = CalDAVClient(baseURL: url)
        } else {
            client = nil
        }
    }

    func sync() async {
        guard let client else { return }
        do {
            let discovered = try await client.discoverCalendars()
            calendars = discovered
            if let first = discovered.first {
                selectedCalendar = first
                tasks = try await client.fetchTasks(from: first.id)
                    .map { Task(title: $0.summary) }
            }
        } catch {
            // Surface errors properly in a later iteration.
        }
    }
}
