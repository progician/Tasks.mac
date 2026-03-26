import Quick
import Nimble
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("Main window") {
            let fakeServer = FakeCalDAVServer()
            var process: Process?
            var appElement: AXUIElement?

            beforeEach {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }
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

            it("shows smart navigation items in the sidebar") {
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

            it("shows task list names from the CalDAV server in the sidebar") {
                _ = try? fakeServer.addCalendar(name: "This Week")
                _ = try? fakeServer.addCalendar(name: "Next Week")
                guard let app = launch() else { return }
                guard UIAXHelper.findFirstElementByRole(
                    in: app, as: kAXOutlineRole, timeout: 5.0
                ) != nil else { fail("Sidebar did not appear"); return }

                let items = UIAXHelper.findAllStaticTextValue(in: app, timeout: 10.0)
                expect(items).to(contain("This Week"))
                expect(items).to(contain("Next Week"))
            }

            it("shows the content header with the active list name and task count from CalDAV") {
                let calendarUID = (try? fakeServer.addCalendar(name: "Shopping")) ?? ""
                _ = try? fakeServer.addTask(summary: "Milk", toCalendar: calendarUID)
                _ = try? fakeServer.addTask(summary: "Eggs", toCalendar: calendarUID)
                _ = try? fakeServer.addTask(summary: "Bread", toCalendar: calendarUID)
                guard let app = launch() else { return }

                let found = UIAXHelper.findAllStaticTextValue(in: app, timeout: 6.0)
                expect(found).to(contain("Shopping"))
                expect(found).to(contain("3"))
            }

            it("shows tasks from the CalDAV server in the task list") {
                let calendarUID = (try? fakeServer.addCalendar(name: "My Tasks")) ?? ""
                _ = try? fakeServer.addTask(summary: "Buy groceries", toCalendar: calendarUID)
                guard let app = launch() else { return }

                let buttons = UIAXHelper.findElementsByRole(in: app, as: kAXButtonRole, timeout: 5.0)
                expect(buttons.count).to(beGreaterThan(0))

                let found = UIAXHelper.findAllStaticTextValue(in: app, timeout: 5.0)
                expect(found).to(contain("Buy groceries"))
            }

            xit("shows the calendar name as a task list name on the sidebar") {
                let CALENDAR_NAME_AS_TASK_LIST_NAME = "Calendar Name To Capture"
                try! fakeServer.addCalendar(name: CALENDAR_NAME_AS_TASK_LIST_NAME)
                guard let app = launch() else { return }

                guard let sidebar = UIAXHelper.findFirstElementByRole(in: app, as: kAXOutlineRole) else {
                    fail("Cannot find side bar")
                    return
                }

                let sidebarItems = UIAXHelper.allStaticTextValues(within: sidebar)
                expect(sidebarItems).to(contain(CALENDAR_NAME_AS_TASK_LIST_NAME))
            }
        }
    }
}
