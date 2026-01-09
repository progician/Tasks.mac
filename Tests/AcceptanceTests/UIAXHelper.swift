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
        guard let childVal = axValue(of: element, attribute: kAXChildrenAttribute as CFString) else { return [] }
        if let arr = childVal as? [AXUIElement] { return arr }
        if let arr = childVal as? [Any] {
            return arr.compactMap { item in
                guard let cf = item as CFTypeRef? else { return nil }
                if CFGetTypeID(cf) == AXUIElementGetTypeID() {
                    return (item as! AXUIElement)
                }
                return nil
            }
        }
        return []
    }

    static func role(of element: AXUIElement) -> String? {
        return axValue(of: element, attribute: kAXRoleAttribute as CFString) as? String
    }

    static func value(of element: AXUIElement) -> String? {
        // kAXValueAttribute may be a CFString or other
        if let v = axValue(of: element, attribute: kAXValueAttribute as CFString) as? String { return v }
        if let t = axValue(of: element, attribute: kAXTitleAttribute as CFString) as? String { return t }
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
            if let windowsVal = axValue(of: appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] {
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

    static func findElementByRole(in element: AXUIElement, as elementRole: String, timeout: TimeInterval = 5.0) -> AXUIElement? {
        if let role = role(of: element), role == elementRole as String {
            return element
        }
        for child in children(of: element) {
            if let found = findElementByRole(in: child, as: elementRole) { return found }
        }

        return nil
    }
}
