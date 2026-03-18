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

            func launchApp(calDAVURL: URL) -> Process? {
                guard let bundlePath = ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] else {
                    return nil
                }
                let execPath = bundlePath + "/Contents/MacOS/Tasks.mac"
                guard FileManager.default.fileExists(atPath: execPath) else { return nil }

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: execPath)
                // Merge the CalDAV URL into the environment so the app knows
                // which server to sync with.  The app reads CALDAV_URL on startup.
                proc.environment = ProcessInfo.processInfo.environment.merging([
                    "CALDAV_URL": calDAVURL.absoluteString,
                ]) { _, new in new }
                proc.standardOutput = Pipe()
                proc.standardError  = Pipe()
                try? proc.run()
                return proc
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

                process = launchApp(calDAVURL: fakeServer.calDAVURL)
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
