import Foundation
import Quick
import Nimble
import TasksCore

// MARK: - XML fixtures

private let emptyMultistatus = """
    <?xml version="1.0" encoding="utf-8"?>
    <multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"/>
    """

private func propfindWithHomeSet(_ href: String) -> String {
    """
    <?xml version="1.0" encoding="utf-8"?>
    <multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <response>
        <href>/</href>
        <propstat>
          <prop><C:calendar-home-set><href>\(href)</href></C:calendar-home-set></prop>
          <status>HTTP/1.1 200 OK</status>
        </propstat>
      </response>
    </multistatus>
    """
}

private func propfindWithPrincipal(_ href: String) -> String {
    """
    <?xml version="1.0" encoding="utf-8"?>
    <multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <response>
        <href>/</href>
        <propstat>
          <prop><current-user-principal><href>\(href)</href></current-user-principal></prop>
          <status>HTTP/1.1 200 OK</status>
        </propstat>
      </response>
    </multistatus>
    """
}

private func calendarListing(calendars: [(href: String, name: String)]) -> String {
    let responses = calendars.map { cal in
        """
          <response>
            <href>\(cal.href)</href>
            <propstat>
              <prop>
                <resourcetype><collection/><C:calendar/></resourcetype>
                <displayname>\(cal.name)</displayname>
              </prop>
              <status>HTTP/1.1 200 OK</status>
            </propstat>
          </response>
        """
    }.joined(separator: "\n")
    return """
        <?xml version="1.0" encoding="utf-8"?>
        <multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        \(responses)
        </multistatus>
        """
}

private func reportWithTasks(tasks: [(uid: String, summary: String)]) -> String {
    let responses = tasks.map { task in
        """
          <response>
            <href>/cal/\(task.uid).ics</href>
            <propstat>
              <prop>
                <C:calendar-data>BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VTODO
        UID:\(task.uid)
        SUMMARY:\(task.summary)
        STATUS:NEEDS-ACTION
        END:VTODO
        END:VCALENDAR
        </C:calendar-data>
              </prop>
              <status>HTTP/1.1 200 OK</status>
            </propstat>
          </response>
        """
    }.joined(separator: "\n")
    return """
        <?xml version="1.0" encoding="utf-8"?>
        <multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
        \(responses)
        </multistatus>
        """
}

// MARK: - Spec

final class CalDAVClientSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let base = URL(string: "http://test.local/")!

        describe("discoverCalendars") {
            var stub: StubHTTPClient!

            beforeEach { stub = StubHTTPClient() }

            context("when the base PROPFIND returns a calendar-home-set") {
                it("uses the home-set URL for the calendar listing") {
                    stub.enqueue(xml: propfindWithHomeSet("/home/"))
                    stub.enqueue(xml: calendarListing(calendars: [("/home/work/", "Work")]))

                    let calendars = try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()

                    expect(calendars.map(\.displayName)).to(equal(["Work"]))
                    expect(stub.requests[1].url).to(equal(URL(string: "http://test.local/home/")))
                }

                it("sends Depth 0 for discovery and Depth 1 for the listing") {
                    stub.enqueue(xml: propfindWithHomeSet("/home/"))
                    stub.enqueue(xml: calendarListing(calendars: []))

                    _ = try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()

                    expect(stub.requests[0].value(forHTTPHeaderField: "Depth")).to(equal("0"))
                    expect(stub.requests[1].value(forHTTPHeaderField: "Depth")).to(equal("1"))
                }

                it("parses multiple calendars") {
                    stub.enqueue(xml: propfindWithHomeSet("/home/"))
                    stub.enqueue(xml: calendarListing(calendars: [
                        ("/home/work/", "Work"),
                        ("/home/personal/", "Personal"),
                        ("/home/shopping/", "Shopping"),
                    ]))

                    let calendars = try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()

                    expect(calendars.map(\.displayName)).to(equal(["Work", "Personal", "Shopping"]))
                    expect(calendars.map(\.id)).to(equal(["/home/work/", "/home/personal/", "/home/shopping/"]))
                }
            }

            context("when the base PROPFIND returns a current-user-principal instead") {
                it("follows the principal URL to find the home-set") {
                    stub.enqueue(xml: propfindWithPrincipal("/principal/"))
                    stub.enqueue(xml: propfindWithHomeSet("/calendars/"))
                    stub.enqueue(xml: calendarListing(calendars: [("/calendars/inbox/", "Inbox")]))

                    let calendars = try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()

                    expect(calendars.map(\.displayName)).to(equal(["Inbox"]))
                    expect(stub.requests).to(haveCount(3))
                }
            }

            context("when the server responds with 401 Unauthorized") {
                it("throws authenticationRequired") {
                    // First PROPFIND (discovery) falls back silently on 401;
                    // the second PROPFIND (listing at baseURL) surfaces the error.
                    stub.enqueue(xml: "", statusCode: 401)
                    stub.enqueue(xml: "", statusCode: 401)

                    await expect {
                        try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()
                    }.to(throwError(CalDAVError.authenticationRequired))
                }
            }

            context("when the HTTP client throws a URLError indicating auth failure") {
                it("throws authenticationRequired for userAuthenticationRequired") {
                    stub.enqueueError(URLError(.userAuthenticationRequired))
                    stub.enqueueError(URLError(.userAuthenticationRequired))

                    await expect {
                        try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()
                    }.to(throwError(CalDAVError.authenticationRequired))
                }

                it("throws authenticationRequired for userCancelledAuthentication") {
                    stub.enqueueError(URLError(.userCancelledAuthentication))
                    stub.enqueueError(URLError(.userCancelledAuthentication))

                    await expect {
                        try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()
                    }.to(throwError(CalDAVError.authenticationRequired))
                }
            }

            context("when neither home-set nor principal is present") {
                it("falls back to listing the base URL directly") {
                    stub.enqueue(xml: emptyMultistatus)
                    stub.enqueue(xml: calendarListing(calendars: [("/shopping/", "Shopping")]))

                    let calendars = try await CalDAVClient(baseURL: base, http: stub).discoverCalendars()

                    expect(calendars.map(\.displayName)).to(equal(["Shopping"]))
                    expect(stub.requests[1].url).to(equal(base))
                }
            }
        }

        describe("fetchTasks") {
            var stub: StubHTTPClient!

            beforeEach { stub = StubHTTPClient() }

            it("parses all VTODO items from the REPORT response") {
                stub.enqueue(xml: reportWithTasks(tasks: [
                    (uid: "task-1", summary: "Buy milk"),
                    (uid: "task-2", summary: "Call dentist"),
                ]))

                let tasks = try await CalDAVClient(baseURL: base, http: stub).fetchTasks(from: "/cal/")

                expect(tasks.map(\.summary)).to(equal(["Buy milk", "Call dentist"]))
                expect(tasks.map(\.uid)).to(equal(["task-1", "task-2"]))
            }

            it("returns an empty array for a calendar with no tasks") {
                stub.enqueue(xml: emptyMultistatus)

                let tasks = try await CalDAVClient(baseURL: base, http: stub).fetchTasks(from: "/cal/")

                expect(tasks).to(beEmpty())
            }

            it("resolves the calendar href relative to the base URL") {
                stub.enqueue(xml: emptyMultistatus)

                _ = try await CalDAVClient(baseURL: base, http: stub).fetchTasks(from: "/calendars/work/")

                expect(stub.requests.first?.url).to(equal(URL(string: "http://test.local/calendars/work/")))
            }

            it("sends a REPORT request") {
                stub.enqueue(xml: emptyMultistatus)

                _ = try await CalDAVClient(baseURL: base, http: stub).fetchTasks(from: "/cal/")

                expect(stub.requests.first?.httpMethod).to(equal("REPORT"))
            }
        }
    }
}
