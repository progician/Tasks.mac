import Quick
import Nimble
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func spec() {
        describe("Main window") {
            let fakeServer = FakeCalDAVServer()
            var process: Process?

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
                fakeServer.stop()
            }

            it("shows smart navigation items in the sidebar") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else { fail("Could not launch the app"); return }

                let appElement = AXUIElementCreateApplication(process!.processIdentifier)
                guard let sidebar = UIAXHelper.findFirstElementByRole(
                    in: appElement, as: kAXOutlineRole, timeout: 5.0
                ) else { fail("Sidebar did not appear"); return }

                let items = UIAXHelper.allStaticTextValues(within: sidebar)
                expect(items).to(contain("Today"))
                expect(items).to(contain("Scheduled"))
                expect(items).to(contain("All"))
                expect(items).to(contain("Completed"))
            }

            it("shows task list names from the CalDAV server in the sidebar") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                _ = try? fakeServer.addCalendar(name: "This Week")
                _ = try? fakeServer.addCalendar(name: "Next Week")

                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else { fail("Could not launch the app"); return }

                let appElement = AXUIElementCreateApplication(process!.processIdentifier)
                guard UIAXHelper.findFirstElementByRole(
                    in: appElement, as: kAXOutlineRole, timeout: 5.0
                ) != nil else { fail("Sidebar did not appear"); return }

                let items = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 10.0)
                expect(items).to(contain("This Week"))
                expect(items).to(contain("Next Week"))
            }

            it("shows the content header with the active list name and task count from CalDAV") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                let calendarUID = (try? fakeServer.addCalendar(name: "Shopping")) ?? ""
                _ = try? fakeServer.addTask(summary: "Milk", toCalendar: calendarUID)
                _ = try? fakeServer.addTask(summary: "Eggs", toCalendar: calendarUID)
                _ = try? fakeServer.addTask(summary: "Bread", toCalendar: calendarUID)

                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else { fail("Could not launch the app"); return }

                let appElement = AXUIElementCreateApplication(process!.processIdentifier)
                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                expect(found).to(contain("Shopping"))
                expect(found).to(contain("3"))
            }

            it("shows tasks from the CalDAV server in the task list") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                let calendarUID = (try? fakeServer.addCalendar(name: "My Tasks")) ?? ""
                _ = try? fakeServer.addTask(summary: "Buy groceries", toCalendar: calendarUID)

                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else { fail("Could not launch the app"); return }

                let appElement = AXUIElementCreateApplication(process!.processIdentifier)
                let buttons = UIAXHelper.findElementsByRole(in: appElement, as: kAXButtonRole, timeout: 5.0)
                expect(buttons.count).to(beGreaterThan(0))

                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 5.0)
                expect(found).to(contain("Buy groceries"))
            }
        }
    }
}
