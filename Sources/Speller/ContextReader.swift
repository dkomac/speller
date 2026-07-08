import AppKit
import ApplicationServices

/// Best-effort reader for information about the current selection, via the
/// Accessibility API (reuses the permission already granted for keystroke
/// simulation). Returns nil whenever the app doesn't expose its text/geometry
/// (e.g. many Electron apps) or anything else goes wrong — callers then fall
/// back to word-only behavior / cursor-relative positioning.
final class ContextReader {
    /// Characters (UTF-16 units) to include on each side of the selection.
    private let window = 200

    /// A bounded window of text around the selection, for language detection.
    func surroundingText() -> String? {
        guard let (element, cfRange) = focusedElementAndRange() else { return nil }

        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String, !fullText.isEmpty else { return nil }

        // Accessibility ranges are UTF-16 units; NSString matches that.
        let ns = fullText as NSString
        let len = ns.length
        let selStart = max(0, min(cfRange.location, len))
        let selEnd = max(selStart, min(cfRange.location + cfRange.length, len))
        let from = max(0, selStart - window)
        let to = min(len, selEnd + window)
        guard from < to else { return nil }

        let snippet = ns.substring(with: NSRange(location: from, length: to - from))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return snippet.isEmpty ? nil : snippet
    }

    /// Fetches the system-wide focused element and its selection range; nil (never a
    /// crash) on any Accessibility failure.
    private func focusedElementAndRange() -> (AXUIElement, CFRange)? {
        let system = AXUIElementCreateSystemWide()
        // Don't let a hung target app stall the popup — cap AX calls at 0.5s.
        AXUIElementSetMessagingTimeout(system, 0.5)

        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange) else { return nil }

        return (element, cfRange)
    }
}
