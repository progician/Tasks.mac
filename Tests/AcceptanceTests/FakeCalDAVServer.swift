import Foundation

/// Controls the fake CalDAV server process from acceptance tests.
///
/// Starts a Python process (`Tests/FakeCalDAV/server.py`) that runs Radicale
/// as a CalDAV backend alongside a lightweight admin HTTP API.  Tests use
/// this class to start/stop the server and to inject or inspect CalDAV data
/// without going through the application — the "back door" described in GOOS.
///
/// Usage:
/// ```swift
/// let server = FakeCalDAVServer()
/// try server.start()
/// defer { server.stop() }
///
/// try server.addTask(summary: "Buy groceries")
/// // … launch app and assert …
/// try server.reset()
/// ```
final class FakeCalDAVServer {

    static let calDAVPort = 5232
    static let adminPort  = 5233

    /// The base URL the app should use to reach the CalDAV server.
    var calDAVURL: URL {
        URL(string: "http://localhost:\(FakeCalDAVServer.calDAVPort)")!
    }

    private let calendarUser = "tasks-test"
    private var process: Process?

    // Resolved at compile time — robust as long as the project layout is stable.
    private var scriptURL: URL {
        URL(fileURLWithPath: #filePath)        // …/Tests/AcceptanceTests/FakeCalDAVServer.swift
            .deletingLastPathComponent()        // …/Tests/AcceptanceTests/
            .deletingLastPathComponent()        // …/Tests/
            .appendingPathComponent("FakeCalDAV")
            .appendingPathComponent("server.py")
    }

    // MARK: - Lifecycle

    func start() throws {
        let proc = Process()
        if let python3 = ProcessInfo.processInfo.environment["AT_PYTHON_PATH"] {
            proc.executableURL = URL(fileURLWithPath: python3)
            proc.arguments = [
                scriptURL.path,
                "--port", "\(FakeCalDAVServer.calDAVPort)",
                "--admin-port", "\(FakeCalDAVServer.adminPort)",
            ]
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [
                "python3", scriptURL.path,
                "--port", "\(FakeCalDAVServer.calDAVPort)",
                "--admin-port", "\(FakeCalDAVServer.adminPort)",
            ]
        }
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError  = FileHandle.nullDevice
        try proc.run()
        process = proc
        try waitUntilReady()
    }

    func stop() {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
    }

    // MARK: - Test data control (admin back door)

    /// Removes all calendars and tasks, restoring the server to a clean state.
    func reset() throws {
        try admin(method: "POST", path: "/reset")
    }

    /// Configures the CalDAV server to require HTTP Basic authentication (RFC 7617).
    ///
    /// After this call, requests without valid credentials will receive a 401 response.
    /// The server is restarted internally to apply the new auth configuration.
    func setupCredentials(user: String, password: String) throws {
        let body: [String: String] = ["user": user, "password": password]
        try admin(method: "POST", path: "/credentials", body: body)
    }

    /// Creates a named calendar on the fake server.
    ///
    /// - Returns: The UID that identifies the calendar (use it when adding tasks).
    @discardableResult
    func addCalendar(name: String, uid: String = UUID().uuidString) throws -> String {
        let body: [String: String] = ["name": name, "uid": uid]
        let data = try admin(method: "POST", path: "/calendars", body: body)
        let response = try JSONDecoder().decode([String: String].self, from: data)
        return response["uid"] ?? uid
    }

    /// Adds a single VTODO item to a named calendar on the fake server.
    ///
    /// - Parameter toCalendar: The UID returned by `addCalendar`.
    /// - Returns: The UID of the created task.
    @discardableResult
    func addTask(uid: String = UUID().uuidString, summary: String, toCalendar calendarUID: String) throws -> String {
        let body: [String: String] = ["uid": uid, "summary": summary, "calendar": calendarUID]
        let data = try admin(method: "POST", path: "/tasks", body: body)
        let response = try JSONDecoder().decode([String: String].self, from: data)
        return response["uid"] ?? uid
    }

    // MARK: - Private

    private func waitUntilReady(timeout: TimeInterval = 10.0) throws {
        let healthURL = URL(string: "http://localhost:\(FakeCalDAVServer.adminPort)/health")!
        let deadline  = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? Data(contentsOf: healthURL)) != nil { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw FakeCalDAVError.serverDidNotStart
    }

    @discardableResult
    private func admin(
        method: String,
        path: String,
        body: [String: String]? = nil
    ) throws -> Data {
        let url = URL(string: "http://localhost:\(FakeCalDAVServer.adminPort)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()

        URLSession.shared.dataTask(with: request) { data, _, error in
            box.data  = data ?? Data()
            box.error = error
            semaphore.signal()
        }.resume()

        semaphore.wait()
        if let error = box.error { throw error }
        return box.data
    }
}

enum FakeCalDAVError: Error {
    case serverDidNotStart
}

// Simple reference-type box to avoid Sendable capture warnings when bridging
// URLSession callbacks back to synchronous callers via a semaphore.
private final class ResultBox: @unchecked Sendable {
    var data: Data = Data()
    var error: (any Error)?
}
