import Quick
import Nimble
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func spec() {
        describe("Tasks.mac") {
            let fakeServer = FakeCalDAVServer()
            var process: Process?
            var appElement: AXUIElement?

            guard AXIsProcessTrusted() else {
                fail("Accessibility permission required to inspect UI")
                return
            }
            guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                fail("AT_BUNDLE_PATH not set — run via `make test`")
                return
            }

            beforeEach {
                try? fakeServer.start()
                try? fakeServer.reset()
            }

            afterEach {
                if let proc = process, proc.isRunning {
                    proc.terminate()
                    proc.waitUntilExit()
                }
                process = nil
                appElement = nil
                fakeServer.stop()
            }

            func launch() -> AXUIElement? {
                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else { fail("Could not launch the app"); return nil }
                appElement = AXUIElementCreateApplication(process!.processIdentifier)
                return appElement
            }

            context("when run without any CalDAV connection") {
                it("shows only the smart items in the sidebar for testing") {
                    guard let app = launch() else { return }
                    guard let sidebar = UIAXHelper.findFirstElementByRole(
                        in: app, as: kAXOutlineRole, timeout: 5.0
                    ) else { fail("Sidebar did not appear"); return }

                    let items = UIAXHelper.allStaticTextValues(within: sidebar)
                    expect(items).to(contain("Today"))
                    expect(items).to(contain("Scheduled"))
                    expect(items).to(contain("All"))
                    expect(items).to(contain("Completed"))
                }
            }

            context("when there are calendars in the CalDAV server") {
                beforeEach {
                    try! fakeServer.addCalendar(name: "This Week")
                    try! fakeServer.addCalendar(name: "Next Week")
                }

                it("shows them as task list names in the sidebar") {
                    guard let app = launch() else { return }
                    guard UIAXHelper.findFirstElementByRole(
                        in: app, as: kAXOutlineRole, timeout: 5.0
                    ) != nil else { fail("Sidebar did not appear"); return }

                    let items = UIAXHelper.findAllStaticTextValue(in: app, timeout: 10.0)
                    expect(items).to(contain("This Week"))
                    expect(items).to(contain("Next Week"))
                }
            }

            context("when the calendar in CalDAV has a number of items") {
                beforeEach {
                    let calendarUID = (try? fakeServer.addCalendar(name: "Shopping")) ?? ""
                    try! fakeServer.addTask(summary: "Milk", toCalendar: calendarUID)
                    try! fakeServer.addTask(summary: "Eggs", toCalendar: calendarUID)
                    try! fakeServer.addTask(summary: "Bread", toCalendar: calendarUID)
                }

                it("shows the content header with the active list name and task count") {
                    guard let app = launch() else { return }

                    let found = UIAXHelper.findAllStaticTextValue(in: app, timeout: 6.0)
                    expect(found).to(contain("Shopping"))
                    expect(found).to(contain("3"))
                }
            }

            context("when a calendar in the CalDAV server has a number of tasks") {
                beforeEach {
                    let calendarUID = (try? fakeServer.addCalendar(name: "My Tasks")) ?? ""
                    try! fakeServer.addTask(summary: "Buy groceries", toCalendar: calendarUID)
                }

                it("shows tasks in the main content area as a list") {
                    guard let app = launch() else { return }

                    let buttons = UIAXHelper.findElementsByRole(in: app, as: kAXButtonRole, timeout: 5.0)
                    expect(buttons.count).to(beGreaterThan(0))

                    let found = UIAXHelper.findAllStaticTextValue(in: app, timeout: 5.0)
                    expect(found).to(contain("Buy groceries"))
                }
            }

            context("when the CalDAV server requires authentication and no credentials are given") {
                beforeEach {
                    try! fakeServer.setupCredentials(user: "foo", password: "bar")
                }

                it("shows an error status in the status message area") {
                    guard let app = launch() else { return }
                    guard let statusMessagePanel = UIAXHelper.findElementById(in: app, id: "statusMessages") else {
                        fail("Could not find status message panel")
                        return
                    }
                    guard let statusText = UIAXHelper.findStaticTextValue(in: statusMessagePanel) else {
                        fail("Could not find status message text")
                        return
                    }
                    expect(statusText).to(contain("requires authentication"))
                }
            }
        }
    }
}
