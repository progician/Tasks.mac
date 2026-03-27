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

    static func findStaticTextValue(in element: AXUIElement, timeout: TimeInterval = 5.0) -> String? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let windowsVal = axValue(of: element, attribute: kAXWindowsAttribute as CFString) as? [AXUIElement] {
                // Application element: search through its windows.
                for win in windowsVal {
                    if let textElem = findFirstStaticText(in: win), let val = value(of: textElem) {
                        return val
                    }
                }
            } else if let textElem = findFirstStaticText(in: element), let val = value(of: textElem) {
                // Container element: search directly within it.
                return val
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
        let start = Date()
        repeat {
            if let found = findFirstElementByRoleSync(in: element, as: elementRole) { return found }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while Date().timeIntervalSince(start) < timeout
        return nil
    }

    private static func findFirstElementByRoleSync(
        in element: AXUIElement,
        as elementRole: String
    ) -> AXUIElement? {
        if role(of: element) == elementRole { return element }
        for child in children(of: element) {
            if let found = findFirstElementByRoleSync(in: child, as: elementRole) { return found }
        }
        return nil
    }

    /// Returns all static text values reachable from `element` without any
    /// timeout polling.  Suitable for asserting within a container element
    /// that is already known to exist.
    static func allStaticTextValues(within element: AXUIElement) -> [String] {
        return findElementsByRoleSync(in: element, as: kAXStaticTextRole)
            .compactMap { value(of: $0) }
    }

    static func findElementsByRole(
        in element: AXUIElement,
        as elementRole: String,
        timeout: TimeInterval = 5.0
    ) -> [AXUIElement] {
        let start = Date()
        repeat {
            let results = findElementsByRoleSync(in: element, as: elementRole)
            if !results.isEmpty { return results }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while Date().timeIntervalSince(start) < timeout
        return []
    }

    private static func findElementsByRoleSync(
        in element: AXUIElement,
        as elementRole: String
    ) -> [AXUIElement] {
        var results = [AXUIElement]()
        if role(of: element) == elementRole { results.append(element) }
        for child in children(of: element) {
            results.append(contentsOf: findElementsByRoleSync(in: child, as: elementRole))
        }
        return results
    }

    /// Finds the first element whose `AXIdentifier` attribute matches `id`,
    /// analogous to `document.getElementById` in HTML.
    ///
    /// The identifier is set in SwiftUI via `.accessibilityIdentifier("...")`.
    static func findElementById(
        in element: AXUIElement,
        id: String,
        timeout: TimeInterval = 5.0
    ) -> AXUIElement? {
        let start = Date()
        repeat {
            if let found = findElementByIdSync(in: element, id: id) { return found }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while Date().timeIntervalSince(start) < timeout
        return nil
    }

    private static func findElementByIdSync(in element: AXUIElement, id: String) -> AXUIElement? {
        if let identifier = axValue(of: element, attribute: kAXIdentifierAttribute as CFString) as? String,
           identifier == id {
            return element
        }
        for child in children(of: element) {
            if let found = findElementByIdSync(in: child, id: id) { return found }
        }
        return nil
    }

    static func findAllStaticTextValue(in appElement: AXUIElement, timeout: TimeInterval = 5.0) -> [String?] {
        let start = Date()
        var lastSnapshot = Set<String>()
        repeat {
            guard let windowsVal = axValue(
                of: appElement, attribute: kAXWindowsAttribute as CFString
            ) as? [AXUIElement] else {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                continue
            }
            let snapshot = Set(windowsVal.flatMap { allStaticTextValues(within: $0) })
            if !snapshot.isEmpty && snapshot == lastSnapshot {
                return Array(snapshot)
            }
            lastSnapshot = snapshot
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        } while Date().timeIntervalSince(start) < timeout
        return Array(lastSnapshot)
    }
}
