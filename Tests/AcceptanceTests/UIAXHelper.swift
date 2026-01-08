import Foundation
import ApplicationServices

enum AXErrorWrapper: Error {
    case axError(AXError)
}

/// Convenience helpers for querying AX elements
struct UIAXHelper {
    static func axValue(of element: AXUIElement, attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard err == .success, let val = value else { return nil }
        return val as AnyObject
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        guard let childVal = axValue(of: element, attribute: kAXChildrenAttribute) else { return [] }
        if let arr = childVal as? [AXUIElement] { return arr }
        if let arr = childVal as? [Any] {
            return arr.compactMap { $0 as? AXUIElement }
        }
        return []
    }

    static func role(of element: AXUIElement) -> String? {
        return axValue(of: element, attribute: kAXRoleAttribute) as? String
    }

    static func value(of element: AXUIElement) -> String? {
        // kAXValueAttribute may be a CFString or other
        if let v = axValue(of: element, attribute: kAXValueAttribute) as? String { return v }
        if let t = axValue(of: element, attribute: kAXTitleAttribute) as? String { return t }
        return nil
    }

    static func findFirstStaticText(in element: AXUIElement) -> AXUIElement? {
        if let role = role(of: element), role == kAXStaticTextRole as String {
            return element
        }
        for child in children(of: element) {
            if let found = findFirstStaticText(in: child) { return found }
        }
        return nil
    }

    static func findStaticTextValue(in appElement: AXUIElement, timeout: TimeInterval = 5.0) -> String? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let windowsVal = axValue(of: appElement, attribute: kAXWindowsAttribute) as? [AXUIElement] {
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
}
