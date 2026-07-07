import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey (⌥Space) using the Carbon Hot Key API.
final class HotkeyManager {
    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        // Install a handler for hot-key-pressed events, passing `self` as userData.
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        // Register ⌥Space. kVK_Space = 0x31; optionKey is the Carbon modifier mask.
        let hotKeyID = EventHotKeyID(signature: OSType(0x53504C52) /* 'SPLR' */, id: 1)
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), hotKeyID,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
