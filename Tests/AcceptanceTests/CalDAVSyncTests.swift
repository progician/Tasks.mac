import Quick
import Nimble
import Foundation
import ApplicationServices

/// Walking skeleton acceptance test for CalDAV synchronisation.
///
/// Verifies the thinnest possible end-to-end vertical slice: a task that
/// exists on a CalDAV server appears in the app's task list after the app
/// syncs on launch.  This test is expected to fail (red) until the CalDAV
/// sync feature is implemented.
class CalDAVSyncSpec: QuickSpec {
    override func spec() {
        describe("CalDAV synchronisation") {
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

            it("shows a task fetched from the CalDAV server") {
                guard AXIsProcessTrusted() else {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }
                guard ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] != nil else {
                    pending("AT_BUNDLE_PATH not set — run via `make test`") { }
                    return
                }

                _ = try? fakeServer.addTask(summary: "Buy groceries")

                process = launchApp(environment: ["CALDAV_URL": fakeServer.calDAVURL.absoluteString])
                guard process != nil else {
                    fail("Could not launch the app")
                    return
                }

                let appElement = AXUIElementCreateApplication(process!.processIdentifier)
                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                expect(found).to(contain("Buy groceries"))
            }
        }
    }
}
