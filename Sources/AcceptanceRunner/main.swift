import Foundation
import ApplicationServices

func axValue(_ element: AXUIElement, attribute: CFString) -> AnyObject? {
    var value: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(element, attribute, &value)
    guard err == .success, let val = value else { return nil }
    return val as AnyObject
}

func children(of element: AXUIElement) -> [AXUIElement] {
    guard let childVal = axValue(element, attribute: kAXChildrenAttribute as CFString) else { return [] }
    if let arr = childVal as? [AXUIElement] { return arr }
    if let arr = childVal as? [AnyObject] { return arr.map { $0 as! AXUIElement } }
    return []
}

func role(of element: AXUIElement) -> String? { axValue(element, attribute: kAXRoleAttribute as CFString) as? String }
func value(of element: AXUIElement) -> String? {
    if let v = axValue(element, attribute: kAXValueAttribute as CFString) as? String { return v }
    if let t = axValue(element, attribute: kAXTitleAttribute as CFString) as? String { return t }
    return nil
}

func findFirstStaticText(in element: AXUIElement) -> AXUIElement? {
    if let r = role(of: element), r == (kAXStaticTextRole as String) { return element }
    for child in children(of: element) {
        if let found = findFirstStaticText(in: child) { return found }
    }
    return nil
}

func findStaticTextValue(in appElement: AXUIElement, timeout: TimeInterval = 5.0) -> String? {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if let windowsVal = axValue(appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] {
            for win in windowsVal {
                if let t = findFirstStaticText(in: win), let val = value(of: t) {
                    return val
                }
            }
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    return nil
}

print("Acceptance runner starting...")
if !AXIsProcessTrusted() {
    fputs("Accessibility permission is missing. Grant access to the runner (Terminal or Xcode) in System Settings → Privacy & Security → Accessibility.\n", stderr)
    exit(2)
}

let execPath = FileManager.default.currentDirectoryPath + "/.build/debug/Tasks.mac"
guard FileManager.default.fileExists(atPath: execPath) else {
    fputs("Executable not found at \(execPath). Run 'swift build' first.\n", stderr)
    exit(3)
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: execPath)
proc.standardOutput = Pipe()
proc.standardError = Pipe()

do {
    try proc.run()
} catch {
    fputs("Failed to launch app: \(error)\n", stderr)
    exit(4)
}

let pid = proc.processIdentifier
let appElement = AXUIElementCreateApplication(pid)

let expected = "Welcome — Acceptance Test"
let found = findStaticTextValue(in: appElement, timeout: 6.0)
if let f = found {
    if f == expected {
        print("OK — found expected label: \(f)")
        proc.terminate(); proc.waitUntilExit()
        exit(0)
    } else {
        fputs("FAIL — label text differs. Found: \(f)\n", stderr)
        proc.terminate(); proc.waitUntilExit()
        exit(5)
    }
} else {
    fputs("FAIL — could not find label text in app UI\n", stderr)
    proc.terminate(); proc.waitUntilExit()
    exit(6)
}
