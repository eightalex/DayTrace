import AppKit
import ApplicationServices
import Foundation

struct ActivitySnapshot: Equatable {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String
    let isDevelopmentContext: Bool
    let isIdle: Bool
}

private struct CapturedTitle {
    let display: String
    let raw: String
}

enum ActivityCapture {
    static let idleThreshold: TimeInterval = 5 * 60

    static func snapshot() -> ActivitySnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = app.localizedName ?? "Невідома програма"
        let idle = idleSeconds() >= idleThreshold
        let title = idle ? CapturedTitle(display: "", raw: "") : activityTitle(
            processIdentifier: app.processIdentifier,
            appName: appName,
            bundleIdentifier: app.bundleIdentifier
        )

        return ActivitySnapshot(
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            windowTitle: title.display,
            isDevelopmentContext: ContextTitleCleaner.isDevelopmentContext(
                appName: appName,
                bundleIdentifier: app.bundleIdentifier,
                rawTitle: title.raw
            ),
            isIdle: idle
        )
    }

    static func accessibilityGranted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func activityTitle(
        processIdentifier: pid_t,
        appName: String,
        bundleIdentifier: String?
    ) -> CapturedTitle {
        let application = AXUIElementCreateApplication(processIdentifier)
        let focusedWebTitle = ContextTitleCleaner.prefersFocusedWebTitle(
            appName: appName,
            bundleIdentifier: bundleIdentifier
        ) ? focusedWebAreaTitle(application: application) : ""

        if !focusedWebTitle.isEmpty {
            let cleaned = ContextTitleCleaner.clean(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                title: focusedWebTitle
            )
            if !cleaned.isEmpty { return CapturedTitle(display: cleaned, raw: focusedWebTitle) }
        }

        let windowTitle = focusedWindowTitle(application: application, processIdentifier: processIdentifier)
        return CapturedTitle(
            display: ContextTitleCleaner.clean(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                title: windowTitle
            ),
            raw: windowTitle
        )
    }

    private static func focusedWindowTitle(application: AXUIElement, processIdentifier: pid_t) -> String {
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

    private static func focusedWebAreaTitle(application: AXUIElement) -> String {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else { return "" }

        var current = focusedValue as! AXUIElement
        for _ in 0..<12 {
            if stringAttribute(kAXRoleAttribute, from: current) == "AXWebArea",
               let title = stringAttribute(kAXTitleAttribute, from: current),
               !title.isEmpty {
                return title
            }

            var parentValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                current,
                kAXParentAttribute as CFString,
                &parentValue
            ) == .success, let parentValue else { break }
            current = parentValue as! AXUIElement
        }
        return ""
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
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

}
