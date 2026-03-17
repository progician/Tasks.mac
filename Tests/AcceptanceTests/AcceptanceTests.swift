import Quick
import Nimble
import XCTest
import Foundation
import ApplicationServices

class AcceptanceSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        func withAXApp(process: Process?, test: (AXUIElement) -> Void) {
            guard AXIsProcessTrusted() else {
                pending("Accessibility permission required to inspect UI") { }
                return
            }
            guard let proc = process else { fail("Process not started"); return }
            test(AXUIElementCreateApplication(proc.processIdentifier))
        }

        describe("Main window") {
            var process: Process!

            func launchApp(execPath: String) -> Process? {
                let newProcess = Process()
                newProcess.executableURL = URL(fileURLWithPath: execPath)
                newProcess.standardOutput = Pipe()
                newProcess.standardError = Pipe()
                do {
                    try newProcess.run()
                } catch {
                    return nil
                }
                return newProcess
            }

            beforeEach {
                if !AXIsProcessTrusted() {
                    let message = "Accessibility permission required to run UI acceptance tests. " +
                        "Grant access to the test runner (Terminal or Xcode) in " +
                        "System Settings → Privacy & Security → Accessibility."
                    pending(message) { }
                    return
                }

                if let bundlePath = ProcessInfo.processInfo.environment["AT_BUNDLE_PATH"] {
                    let execPath = bundlePath + "/Contents/MacOS/Tasks.mac"
                    guard FileManager.default.fileExists(atPath: execPath) else {
                        fail("Executable not built at \(execPath). " +
                            "Run `swift build` before running tests or run tests via Xcode.")
                        return
                    }

                    process = launchApp(execPath: execPath)
                    if process == nil {
                        fail("Cannot launch executable")
                        return
                    }

                    try? await Task.sleep(nanoseconds: 200_000_000)
                } else {
                    fail("'AT_BUNDLE_PATH' environment variable must be set!")
                }
            }

            afterEach {
                if let proc = process, proc.isRunning {
                    proc.terminate()
                    proc.waitUntilExit()
                }
                process = nil
            }

            it("shows sidebar with list items") {
                withAXApp(process: process) { appElement in
                    let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                    expect(found).to(contain("Today"))
                    expect(found).to(contain("Scheduled"))
                    expect(found).to(contain("All"))
                    expect(found).to(contain("Completed"))
                    expect(found).to(contain("[01] This Week"))
                    expect(found).to(contain("[02] Next Week"))
                }
            }

            it("shows content header with title and task count") {
                withAXApp(process: process) { appElement in
                    let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                    expect(found).to(contain("[01] This Week"))
                    expect(found).to(contain("12"))
                    expect(found).to(contain("277 Completed"))
                }
            }

            it("shows task list with checkbox elements") {
                withAXApp(process: process) { mainElement in
                    let buttons = UIAXHelper.findElementsByRole(in: mainElement, as: kAXButtonRole)
                    expect(buttons.count).to(beGreaterThan(0))
                }
            }

            it("shows task with text content") {
                withAXApp(process: process) { appElement in
                    let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                    expect(found).to(contain("Organize emails"))
                }
            }

            it("has a sidebar") {
                withAXApp(process: process) { mainElement in
                    let sidebarElem = UIAXHelper.findFirstElementByRole(in: mainElement, as: kAXOutlineRole)
                    expect(sidebarElem).notTo(beNil())
                }
            }

            it("shows sidebar item count badges") {
                withAXApp(process: process) { appElement in
                    let found = UIAXHelper.findAllStaticTextValue(in: appElement, timeout: 6.0)
                    expect(found).to(contain("Today"))
                    expect(found).to(contain("5"))
                    expect(found).to(contain("Scheduled"))
                    expect(found).to(contain("3"))
                    expect(found).to(contain("All"))
                    expect(found).to(contain("44"))
                }
            }
        }
    }
}
