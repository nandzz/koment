import AppKit

let syntheticCopyMarker: Int64 = 0x434D5443

private func copyTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        Unmanaged<CopyTapMonitor>.fromOpaque(userInfo)
            .takeUnretainedValue()
            .receive(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}

final class CopyTapMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastPress: CFAbsoluteTime = 0
    private let interval: CFAbsoluteTime
    private let action: () -> Void

    var isRunning: Bool {
        tap != .none
    }

    init(interval: CFAbsoluteTime = 0.4, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard !isRunning, AXIsProcessTrusted() else { return isRunning }

        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: copyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(.none, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = .none
        runLoopSource = .none
        lastPress = 0
    }

    fileprivate func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard type == .keyDown, isCopy(event), !NSApp.isActive else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastPress <= interval else {
            lastPress = now
            return
        }
        lastPress = 0
        DispatchQueue.main.async { [weak self] in self?.action() }
    }

    private func isCopy(_ event: CGEvent) -> Bool {
        guard
            event.getIntegerValueField(.keyboardEventKeycode) == 0x08,
            event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
            event.getIntegerValueField(.eventSourceUserData) != syntheticCopyMarker,
            event.getIntegerValueField(.eventSourceUnixProcessID) != Int64(getpid())
        else {
            return false
        }
        let flags = event.flags
        return flags.contains(.maskCommand)
            && !flags.contains(.maskShift)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
    }
}
