import AppKit
import ApplicationServices

struct SelectionCapture {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func capture() -> (capture: Capture?, report: CaptureReport) {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "unknown"
        let window = frontApp.flatMap { focusedWindow(pid: $0.processIdentifier) }
        let windowTitle = window.flatMap { string(of: $0, attribute: kAXTitleAttribute) }
        let documentPath = window.flatMap { documentURL(of: $0) }
        let bundleIdentifier = frontApp?.bundleIdentifier
        let sourceURL = window.flatMap { address(of: $0) }
        let element = focusedElement()
        let role = element.flatMap { string(of: $0, attribute: kAXRoleAttribute) }
        let axSelected = element.flatMap { string(of: $0, attribute: kAXSelectedTextAttribute) }
        let axLine = element.flatMap { line(of: $0) }
        let context = element.map { surrounding(of: $0) } ?? (before: [], after: [])
        let screenFrame = cocoa(element.flatMap { bounds(of: $0) } ?? window.flatMap { frame(of: $0) })

        var report = CaptureReport(
            trusted: isTrusted,
            appName: appName,
            focusedRole: role,
            axSelectedLength: axSelected?.count ?? 0,
            clipboardLength: 0,
            documentPath: documentPath,
            windowTitle: windowTitle,
            bundleIdentifier: bundleIdentifier,
            sourceURL: sourceURL,
            screenFrame: screenFrame,
            axLine: axLine,
            method: "none"
        )

        if let axSelected, !axSelected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report.method = "ax-selected-text"
            let capture = Capture(
                selectedText: axSelected,
                appName: appName,
                documentPath: documentPath,
                windowTitle: windowTitle,
                bundleIdentifier: bundleIdentifier,
                sourceURL: sourceURL,
                screenFrame: screenFrame,
                axLine: axLine,
                contextBefore: context.before,
                contextAfter: context.after,
                method: report.method
            )
            return (capture, report)
        }

        let copied = copyViaKeystroke()
        report.clipboardLength = copied?.count ?? 0
        guard let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (.none, report)
        }
        report.method = "clipboard"
        let capture = Capture(
            selectedText: copied,
            appName: appName,
            documentPath: documentPath,
            windowTitle: windowTitle,
            bundleIdentifier: bundleIdentifier,
            sourceURL: sourceURL,
            screenFrame: screenFrame,
            axLine: axLine,
            contextBefore: context.before,
            contextAfter: context.after,
            method: report.method
        )
        return (capture, report)
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var reference: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &reference) == .success,
            let value = reference,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return .none
        }
        return (value as! AXUIElement)
    }

    private func focusedWindow(pid: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(pid)
        var reference: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &reference) == .success,
            let value = reference,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return .none
        }
        return (value as! AXUIElement)
    }

    private func string(of element: AXUIElement, attribute: String) -> String? {
        var reference: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &reference) == .success else {
            return .none
        }
        return reference as? String
    }

    private func documentURL(of window: AXUIElement) -> String? {
        guard let raw = string(of: window, attribute: kAXDocumentAttribute) else { return .none }
        if let url = URL(string: raw), url.isFileURL {
            return url.path
        }
        return raw.hasPrefix("/") ? raw : .none
    }

    private func address(of window: AXUIElement) -> String? {
        var reference: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXURLAttribute as CFString, &reference) == .success,
            let value = reference
        else {
            return .none
        }
        if let url = value as? URL {
            return url.absoluteString
        }
        return value as? String
    }

    private func bounds(of element: AXUIElement) -> CGRect? {
        guard
            var range = selectedRange(of: element),
            let rangeValue = AXValueCreate(.cfRange, &range)
        else {
            return .none
        }

        var reference: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeValue as CFTypeRef,
                &reference
            ) == .success,
            let value = reference,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return .none
        }

        var rect = CGRect.zero
        guard AXValueGetValue((value as! AXValue), .cgRect, &rect), rect.width > 0, rect.height > 0 else {
            return .none
        }
        return rect
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var positionReference: CFTypeRef?
        var sizeReference: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionReference) == .success,
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeReference) == .success,
            let positionValue = positionReference,
            let sizeValue = sizeReference,
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return .none
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue((positionValue as! AXValue), .cgPoint, &origin),
            AXValueGetValue((sizeValue as! AXValue), .cgSize, &size),
            size.width > 0,
            size.height > 0
        else {
            return .none
        }
        return CGRect(origin: origin, size: size)
    }

    private func cocoa(_ rect: CGRect?) -> CGRect? {
        guard let rect, let primary = NSScreen.screens.first else { return .none }
        return CGRect(
            x: rect.minX,
            y: primary.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func selectedRange(of element: AXUIElement) -> CFRange? {
        var rangeReference: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeReference) == .success,
            let rangeValue = rangeReference,
            CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return .none
        }
        var range = CFRange()
        guard AXValueGetValue((rangeValue as! AXValue), .cfRange, &range) else { return .none }
        return range
    }

    private func surrounding(of element: AXUIElement) -> (before: [String], after: [String]) {
        guard
            let range = selectedRange(of: element),
            let text = string(of: element, attribute: kAXValueAttribute),
            text.utf16.count < 400_000
        else {
            return (before: [], after: [])
        }
        let full = text as NSString
        let start = min(max(0, range.location), full.length)
        let end = min(max(start, start + range.length), full.length)
        let before = full.substring(to: start).components(separatedBy: .newlines)
        let after = full.substring(from: end).components(separatedBy: .newlines)
        return (
            before: Array(before.dropLast().suffix(3)),
            after: Array(after.dropFirst().prefix(3))
        )
    }

    private func line(of element: AXUIElement) -> Int? {
        guard let range = selectedRange(of: element) else { return .none }

        var lineReference: CFTypeRef?
        let index = NSNumber(value: range.location)
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXLineForIndexParameterizedAttribute as CFString,
                index as CFTypeRef,
                &lineReference
            ) == .success,
            let zeroBased = lineReference as? Int
        else {
            return .none
        }
        return zeroBased + 1
    }

    private func copyViaKeystroke() -> String? {
        guard isTrusted else { return .none }

        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        let changeCount = pasteboard.changeCount
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.setIntegerValueField(.eventSourceUserData, value: syntheticCopyMarker)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.setIntegerValueField(.eventSourceUserData, value: syntheticCopyMarker)
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        var waited = 0
        while pasteboard.changeCount == changeCount && waited < 60 {
            usleep(10_000)
            waited += 1
        }
        guard pasteboard.changeCount != changeCount else { return .none }

        let copied = pasteboard.string(forType: .string)
        if let previous {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }
        return copied
    }
}
