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

                if let bundlePath = ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] {
                    let execPath = bundlePath + "/Contents/MacOS/Tasks.mac"
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
                } else {
                    fail("'AT_BUNDLE_PATH' environment variable must be set!")
                }                
            }

            afterEach {
                if let p = process, p.isRunning {
                    p.terminate()
                    p.waitUntilExit()
                }
                process = nil
            }

            it("shows sidebar with list items") {
                if !AXIsProcessTrusted() {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }

                guard let p = process else { fail("Process not started"); return }
                let pid = p.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)
                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                
                // Verify sidebar is showing expected items from different sections
                expect(found).to(contain("Today"))
                expect(found).to(contain("Scheduled"))
                expect(found).to(contain("All"))
                expect(found).to(contain("Completed"))
                expect(found).to(contain("[01] This Week"))
                expect(found).to(contain("[02] Next Week"))
            }

            it("shows content header with title and task count") {
                if !AXIsProcessTrusted() {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }

                guard let p = process else { fail("Process not started"); return }
                let pid = p.processIdentifier
                let appElement = AXUIElementCreateApplication(pid)
                let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                
                // Verify content header is visible
                expect(found).to(contain("[01] This Week"))
                expect(found).to(contain("12"))
                expect(found).to(contain("277 Completed"))
            }

            it("has a sidebar") {
                if !AXIsProcessTrusted() {
                    pending("Accessibility permission required to inspect UI") { }
                    return
                }


                guard let p = process else { fail("Process not started"); return }
                let pid = p.processIdentifier
                let mainElement = AXUIElementCreateApplication(pid)                

                let sidebarElem = UIAXHelper.findFirstElementByRole(in: mainElement, as: kAXOutlineRole)
                expect(sidebarElem).notTo(beNil())
            }
        }
    }
}
