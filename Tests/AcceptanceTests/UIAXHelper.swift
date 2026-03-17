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
        if let childrenArray = childVal as? [AXUIElement] { return childrenArray }
        if let childrenArray = childVal as? [Any] {
            return childrenArray.compactMap { item in
                guard let childTypeRef = item as CFTypeRef? else { return nil }
                guard CFGetTypeID(childTypeRef) == AXUIElementGetTypeID() else { return nil }
                // swiftlint:disable:next force_cast
                return (item as! AXUIElement)
            }
        }
        return []
    }

    static func role(of element: AXUIElement) -> String? {
        return axValue(of: element, attribute: kAXRoleAttribute as CFString) as? String
    }

    static func value(of element: AXUIElement) -> String? {
        // kAXValueAttribute may be a CFString or other
        if let valueAttribute = axValue(of: element, attribute: kAXValueAttribute as CFString) as? String {
            return valueAttribute
        }
        if let titleAttribute = axValue(of: element, attribute: kAXTitleAttribute as CFString) as? String {
            return titleAttribute
        }
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
                    if let textElem = findFirstStaticText(in: win), let val = value(of: textElem) {
                        return val
                    }
                }
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return nil
    }

    static func findFirstElementByRole(
        in element: AXUIElement,
        as elementRole: String,
        timeout: TimeInterval = 5.0
    ) -> AXUIElement? {
        if let role = role(of: element), role == elementRole as String {
            return element
        }
        for child in children(of: element) {
            if let found = findFirstElementByRole(in: child, as: elementRole) { return found }
        }

        return nil
    }

    static func findElementsByRole(
        in element: AXUIElement,
        as elementRole: String,
        timeout: TimeInterval = 5.0
    ) -> [AXUIElement] {
        var results = [AXUIElement]()
        if let role = role(of: element), role == elementRole as String {
            results.append(element)
        }
        for child in children(of: element) {
            let found = findElementsByRole(in: child, as: elementRole, timeout: timeout)
            results.append(contentsOf: found)
        }
        return results
    }

    static func findAllStaticTextValue(in appElement: AXUIElement, timeout: TimeInterval = 5.0) -> [String?] {
        var results = [String?]()
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let windowsVal = axValue(of: appElement, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] {
                for win in windowsVal {
                    let textElems = findElementsByRole(in: win, as: kAXStaticTextRole)
                    results.append(contentsOf: textElems.map { value(of: $0) })
                }
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return results
    }
}
