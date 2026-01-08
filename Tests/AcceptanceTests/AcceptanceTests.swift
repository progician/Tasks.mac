import XCTest
import Foundation
import ApplicationServices

final class AcceptanceTests: XCTestCase {
    var process: Process?

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Accessibility permission required
        if !AXIsProcessTrusted() {
            throw XCTSkip("Accessibility permission required to run UI acceptance tests. Grant access to the test runner (Terminal or Xcode) in System Settings → Privacy & Security → Accessibility.")
        }

        // Path to the built executable. `swift test` builds products into .build/debug
        let execPath = FileManager.default.currentDirectoryPath + "/.build/debug/Tasks.mac"
        guard FileManager.default.fileExists(atPath: execPath) else {
            throw XCTSkip("Executable not built at \(execPath). Run `swift build` before running tests or run tests via Xcode.")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: execPath)
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        try proc.run()
        self.process = proc
        // small delay for app to start
        Thread.sleep(forTimeInterval: 0.2)
    }

    override func tearDownWithError() throws {
        if let p = process, p.isRunning {
            p.terminate()
            p.waitUntilExit()
        }
        process = nil
    }

    func testMainWindowLabelShowsExpectedText() throws {
        guard let proc = process else { throw XCTSkip("Process not started") }

        let pid = proc.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // try to find static text value within timeout
        let found = UIAXHelper.findStaticTextValue(in: appElement, timeout: 6.0)
        XCTAssertEqual(found, "Welcome — Acceptance Test")
    }
}
