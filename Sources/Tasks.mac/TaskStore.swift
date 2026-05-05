import Foundation

enum ServerConfiguration {
    case generic(url: String)
    case nextcloud(serverURL: String, username: String)
    case nextcloudSSO(calDAVURL: String, loginName: String, appPassword: String)
}

@MainActor
final class TaskStore: ObservableObject {
    @Published var calendars: [CalDAVCalendar] = []
    @Published var tasks: [Task] = []
    @Published var selectedCalendar: CalDAVCalendar?
    @Published var syncError: String?
    @Published var lastSync: Date?
    @Published var hasLocalChanges: Bool = false
    @Published var serverAddress: String?
    @Published var nextcloudServerURL: String?
    @Published var nextcloudUsername: String?

    private var client: CalDAVClient?
    private let storage: ServerAddressStorage

    init() {
        let domain = ProcessInfo.processInfo.environment["AT_DEFAULTS_DOMAIN"]
        let defaults = domain.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        storage = ServerAddressStorage(defaults: defaults)

        if let envURL = ProcessInfo.processInfo.environment["CALDAV_URL"] {
            // If we have stored Nextcloud settings that match this host, prefer
            // the constructed Nextcloud CalDAV URL for the stored username.
            let adjusted = resolveNextcloudCalDAVURLIfNeeded(
                base: envURL,
                storedServerURL: storage.loadNextcloudServerURL(),
                storedUsername: storage.loadNextcloudUsername()
            )
            serverAddress = adjusted
            if let url = URL(string: adjusted) {
                client = CalDAVClient(baseURL: url)
            }
        } else if let ncServerURL = storage.loadNextcloudServerURL(),
                  let ncUsername = storage.loadNextcloudUsername() {
            nextcloudServerURL = ncServerURL
            nextcloudUsername = ncUsername
            let constructed = constructNextcloudCalDAVURL(serverURL: ncServerURL, username: ncUsername)
            serverAddress = constructed
            if let url = URL(string: constructed) {
                client = CalDAVClient(baseURL: url)
            }
        } else if let rawURL = storage.load() {
            serverAddress = rawURL
            if let url = URL(string: rawURL) {
                client = CalDAVClient(baseURL: url)
            }
        }
    }

    func updateServerConfiguration(_ config: ServerConfiguration) {
        storage.clear()
        switch config {
        case .generic(let url):
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            serverAddress = trimmed.isEmpty ? nil : trimmed
            nextcloudServerURL = nil
            nextcloudUsername = nil
            if let address = serverAddress, let url = URL(string: address) {
                storage.save(address)
                client = CalDAVClient(baseURL: url)
            } else {
                client = nil
            }
        case .nextcloud(let serverURL, let username):
            let constructed = constructNextcloudCalDAVURL(serverURL: serverURL, username: username)
            serverAddress = constructed
            nextcloudServerURL = serverURL
            nextcloudUsername = username
            storage.saveNextcloudSettings(serverURL: serverURL, username: username)
            if let url = URL(string: constructed) {
                client = CalDAVClient(baseURL: url)
            }
        case .nextcloudSSO(let calDAVURL, let loginName, let appPassword):
            serverAddress = calDAVURL
            nextcloudServerURL = nil
            nextcloudUsername = loginName
            if let url = URL(string: calDAVURL) {
                client = CalDAVClient(
                    baseURL: url,
                    credential: CalDAVCredential(username: loginName, password: appPassword)
                )
            }
            _Concurrency.Task { await sync() }
        }
    }

    func selectCalendar(_ calendar: CalDAVCalendar) async {
        selectedCalendar = calendar
        guard let client else { return }
        do {
            tasks = try await client.fetchTasks(from: calendar.id)
                .map { Task(title: $0.summary) }
        } catch CalDAVError.authenticationRequired {
            syncError = "CalDAV server requires authentication"
        } catch {
            // Surface errors properly in a later iteration.
        }
    }

    func sync() async {
        guard let client else { return }
        syncError = nil
        do {
            let discovered = try await client.discoverCalendars()
            calendars = discovered
            if let first = discovered.first {
                await selectCalendar(first)
            }
            lastSync = Date()
        } catch CalDAVError.authenticationRequired {
            syncError = "CalDAV server requires authentication"
        } catch {
            // Surface errors properly in a later iteration.
        }
    }
}
