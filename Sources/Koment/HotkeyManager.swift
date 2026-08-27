import AppKit
import Carbon.HIToolbox

private var registeredAction: (() -> Void)?

private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        registeredAction?()
    }
    return noErr
}

private let virtualKeyCodes: [String: UInt32] = [
    "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
    "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
    "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
    "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
    "y": 0x10, "z": 0x06, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
    "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D
]

final class HotkeyManager {
    private var hotkeyReference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?

    func register(config: Config, action: @escaping () -> Void) -> Bool {
        guard let keyCode = virtualKeyCodes[config.hotkeyKey.lowercased()] else { return false }
        registeredAction = action

        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &specification,
            .none,
            &handlerReference
        )

        let identifier = EventHotKeyID(signature: OSType(0x43434D54), id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifierMask(config.hotkeyModifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotkeyReference
        )
        return status == noErr
    }

    private func modifierMask(_ names: [String]) -> UInt32 {
        var mask: UInt32 = 0
        for name in names {
            switch name.lowercased() {
            case "command", "cmd": mask |= UInt32(cmdKey)
            case "option", "alt": mask |= UInt32(optionKey)
            case "control", "ctrl": mask |= UInt32(controlKey)
            case "shift": mask |= UInt32(shiftKey)
            default: break
            }
        }
        return mask
    }

    func describe(_ config: Config) -> String {
        var symbols = ""
        for name in config.hotkeyModifiers {
            switch name.lowercased() {
            case "control", "ctrl": symbols += "\u{2303}"
            case "option", "alt": symbols += "\u{2325}"
            case "shift": symbols += "\u{21E7}"
            case "command", "cmd": symbols += "\u{2318}"
            default: break
            }
        }
        return symbols + config.hotkeyKey.uppercased()
    }
}
