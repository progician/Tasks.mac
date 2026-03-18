import Foundation

public struct CalDAVCalendar: Identifiable {
    public let id: String          // href, e.g. "/this-week-uid/"
    public let displayName: String
}

public struct CalDAVTask {
    public let uid: String
    public let summary: String
}

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

/// Minimal CalDAV client that discovers calendars and fetches VTODO objects.
///
/// Discovery order:
///   1. PROPFIND <base> Depth:0  →  calendar-home-set
///   2. If absent, follow current-user-principal and try again
///   3. Fall back to treating <base> itself as the calendar home
///
/// XPath queries use local-name() predicates so they match elements regardless
/// of the namespace prefix the server chooses to use.
public struct CalDAVClient: Sendable {
    let baseURL: URL
    private let http: any HTTPClient

    public init(baseURL: URL, http: any HTTPClient = URLSession.shared) {
        self.baseURL = baseURL
        self.http = http
    }

    // MARK: - Public API

    public func discoverCalendars() async throws -> [CalDAVCalendar] {
        let homeURL = await resolvedCalendarHome()
        return try await listCalendars(at: homeURL)
    }

    public func fetchTasks(from calendarHref: String) async throws -> [CalDAVTask] {
        guard let url = URL(string: calendarHref, relativeTo: baseURL)?.absoluteURL else { return [] }
        let data = try await calendarQuery(url: url)
        return parseVTODOs(from: data)
    }

    // MARK: - Discovery

    private func resolvedCalendarHome() async -> URL {
        guard let data = try? await propfind(url: baseURL, depth: "0", props: [
            "<d:current-user-principal/>",
            "<c:calendar-home-set/>",
        ]) else { return baseURL }

        let homeSetXPath  = "//*[local-name()='calendar-home-set']/*[local-name()='href']"
        let principalXPath = "//*[local-name()='current-user-principal']/*[local-name()='href']"

        if let href = firstStringValue(in: data, xpath: homeSetXPath),
           let url  = URL(string: href, relativeTo: baseURL)?.absoluteURL {
            return url
        }

        if let principal = firstStringValue(in: data, xpath: principalXPath),
           let principalURL = URL(string: principal, relativeTo: baseURL)?.absoluteURL,
           let principalData = try? await propfind(url: principalURL, depth: "0", props: [
               "<c:calendar-home-set/>",
           ]),
           let href = firstStringValue(in: principalData, xpath: homeSetXPath),
           let url  = URL(string: href, relativeTo: baseURL)?.absoluteURL {
            return url
        }

        return baseURL
    }

    private func listCalendars(at homeURL: URL) async throws -> [CalDAVCalendar] {
        let data = try await propfind(url: homeURL, depth: "1", props: [
            "<d:resourcetype/>",
            "<d:displayname/>",
        ])
        return parseCalendars(from: data)
    }

    // MARK: - HTTP

    private func propfind(url: URL, depth: String, props: [String]) async throws -> Data {
        let body = """
            <?xml version="1.0" encoding="utf-8"?>
            <d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
              <d:prop>
            \(props.map { "    \($0)" }.joined(separator: "\n"))
              </d:prop>
            </d:propfind>
            """
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(depth, forHTTPHeaderField: "Depth")
        request.httpBody = body.data(using: .utf8)
        let (data, _) = try await http.data(for: request)
        return data
    }

    private func calendarQuery(url: URL) async throws -> Data {
        let body = """
            <?xml version="1.0" encoding="utf-8"?>
            <c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
              <d:prop>
                <d:getetag/>
                <c:calendar-data/>
              </d:prop>
              <c:filter>
                <c:comp-filter name="VCALENDAR">
                  <c:comp-filter name="VTODO"/>
                </c:comp-filter>
              </c:filter>
            </c:calendar-query>
            """
        var request = URLRequest(url: url)
        request.httpMethod = "REPORT"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.httpBody = body.data(using: .utf8)
        let (data, _) = try await http.data(for: request)
        return data
    }

    // MARK: - XML parsing

    private func firstStringValue(in data: Data, xpath: String) -> String? {
        guard let doc = try? XMLDocument(data: data, options: []) else { return nil }
        return (try? doc.nodes(forXPath: xpath))?
            .first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseCalendars(from data: Data) -> [CalDAVCalendar] {
        guard let doc = try? XMLDocument(data: data, options: []) else { return [] }

        // Responses whose resourcetype contains a {caldav}calendar element
        let responseXPath = "//*[local-name()='response'][.//*[local-name()='calendar']]"
        guard let responses = try? doc.nodes(forXPath: responseXPath) else { return [] }

        return responses.compactMap { response in
            guard
                let href = (try? response.nodes(forXPath: ".//*[local-name()='href']"))?
                    .first?.stringValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !href.isEmpty
            else { return nil }

            let name = (try? response.nodes(forXPath: ".//*[local-name()='displayname']"))?
                .first?.stringValue ?? href

            return CalDAVCalendar(id: href, displayName: name)
        }
    }

    // MARK: - iCalendar parsing

    private func parseVTODOs(from data: Data) -> [CalDAVTask] {
        guard let doc = try? XMLDocument(data: data, options: []) else { return [] }
        guard let responses = try? doc.nodes(forXPath: "//*[local-name()='response']") else { return [] }

        return responses.compactMap { response in
            guard let ics = (try? response.nodes(forXPath: ".//*[local-name()='calendar-data']"))?
                .first?.stringValue
            else { return nil }
            return parseVTODO(from: ics)
        }
    }

    private func parseVTODO(from ics: String) -> CalDAVTask? {
        var uid: String?
        var summary: String?
        var inVTODO = false
        for line in ics.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "BEGIN:VTODO" { inVTODO = true; continue }
            if trimmed == "END:VTODO" { inVTODO = false; continue }
            guard inVTODO else { continue }
            if trimmed.hasPrefix("UID:") { uid = String(trimmed.dropFirst(4)) }
            if trimmed.hasPrefix("SUMMARY:") { summary = String(trimmed.dropFirst(8)) }
        }
        guard let uid, let summary else { return nil }
        return CalDAVTask(uid: uid, summary: summary)
    }
}
