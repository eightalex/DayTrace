import AppKit
import ApplicationServices
import Foundation

struct ActivitySnapshot: Equatable {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String
    let isIdle: Bool
}

enum ActivityCapture {
    static let idleThreshold: TimeInterval = 5 * 60

    static func snapshot() -> ActivitySnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let idle = idleSeconds() >= idleThreshold
        let title = idle ? "" : focusedWindowTitle(processIdentifier: app.processIdentifier)

        return ActivitySnapshot(
            appName: app.localizedName ?? "Невідома програма",
            bundleIdentifier: app.bundleIdentifier,
            windowTitle: normalized(title),
            isIdle: idle
        )
    }

    static func accessibilityGranted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func focusedWindowTitle(processIdentifier: pid_t) -> String {
        let application = AXUIElementCreateApplication(processIdentifier)
        var windowValue: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        guard windowResult == .success, let windowValue else {
            return cgWindowTitle(processIdentifier: processIdentifier)
        }

        let window = windowValue as! AXUIElement
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult == .success, let title = titleValue as? String {
            return title
        }
        return cgWindowTitle(processIdentifier: processIdentifier)
    }

    private static func cgWindowTitle(processIdentifier: pid_t) -> String {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return ""
        }

        for window in windows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                  ownerPID == Int(processIdentifier),
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            if let title = window[kCGWindowName as String] as? String, !title.isEmpty {
                return title
            }
        }
        return ""
    }

    private static func idleSeconds() -> TimeInterval {
        let eventTypes: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel]
        return eventTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    private static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
