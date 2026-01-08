import Quick
import Nimble
import XCTest
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    override func spec() {
        describe("Main window") {
            var process: Process!

            beforeEach {
                // skip early if Accessibility not granted
                if !AXIsProcessTrusted() {
                    pending("Accessibility permission required to run UI acceptance tests. Grant access to the test runner (Terminal or Xcode) in System Settings → Privacy & Security → Accessibility.") { }
                    return
                }

                let execPath = FileManager.default.currentDirectoryPath + "/.build/debug/Tasks.mac"
                guard FileManager.default.fileExists(atPath: execPath) else {
                    fail("Executable not built at \(execPath). Run `swift build` before running tests or run tests via Xcode.")
                    return
                }

                process = Process()
                process.executableURL = URL(fileURLWithPath: execPath)
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    fail("Failed to launch app: \(error)")
                    return
                }

                // small delay for app to start
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            afterEach {
                if let p = process, p.isRunning {
                    p.terminate()
                    p.waitUntilExit()
                }
                process = nil
            }

            it("shows the expected label") {
                if !AXIsProcessTrusted() {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }

                guard let p = process else { fail("Process not started"); return }
                let pid = p.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)
                let found = UIAXHelper.findStaticTextValue(in: appElement, timeout: 6.0)
                expect(found).to(equal("Welcome — Acceptance Test"))
            }
        }
    }
}
