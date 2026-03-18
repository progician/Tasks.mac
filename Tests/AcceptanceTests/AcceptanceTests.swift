import Quick
import Nimble
import XCTest
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    override func spec() {
        describe("Main window") {
            var process: Process?

            beforeEach {
                process = launchApp()
            }

            afterEach {
                if let proc = process, proc.isRunning {
                    proc.terminate()
                    proc.waitUntilExit()
                }
                process = nil
            }

            it("shows the sidebar with navigation items and badges") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard let proc = process else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                let appElement = AXUIElementCreateApplication(proc.processIdentifier)
                guard let sidebar = UIAXHelper.findFirstElementByRole(
                    in: appElement, as: kAXOutlineRole, timeout: 5.0
                ) else {
                    fail("Sidebar did not appear")
                    return
                }

                let items = UIAXHelper.allStaticTextValues(within: sidebar)
                expect(items).to(contain("Today"))
                expect(items).to(contain("Scheduled"))
                expect(items).to(contain("All"))
                expect(items).to(contain("Completed"))
                expect(items).to(contain("[01] This Week"))
                expect(items).to(contain("[02] Next Week"))
                // Badges
                expect(items).to(contain("5"))
                expect(items).to(contain("3"))
                expect(items).to(contain("44"))
            }

            it("shows the content header with the active task list and count") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard let proc = process else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                let appElement = AXUIElementCreateApplication(proc.processIdentifier)
                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                expect(found).to(contain("[01] This Week"))
                expect(found).to(contain("12"))
                expect(found).to(contain("277 Completed"))
            }

            it("shows the task list with checkboxes and task items") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard let proc = process else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                let appElement = AXUIElementCreateApplication(proc.processIdentifier)
                let buttons = UIAXHelper.findElementsByRole(in: appElement, as: kAXButtonRole, timeout: 5.0)
                expect(buttons.count).to(beGreaterThan(0))

                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 5.0)
                expect(found).to(contain("Organize emails"))
            }
        }
    }
}
