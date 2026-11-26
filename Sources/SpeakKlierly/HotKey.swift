import Carbon.HIToolbox

/// A system-wide hotkey using Carbon's `RegisterEventHotKey`.
/// Works in every app and doesn't need Accessibility permission. Reports both press and release.
@MainActor
final class HotKey {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// `id` must be unique per hotkey in this app.
    init(id: UInt32) {
        self.id = id
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var firedID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &firedID
                )
                let kind = GetEventKind(event)
                // Carbon delivers hotkey events on the main thread.
                return MainActor.assumeIsolated {
                    let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                    // Every HotKey's handler sees every hotkey event; only react to our own.
                    guard firedID.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
                    if kind == UInt32(kEventHotKeyPressed) {
                        hotKey.onPress?()
                    } else if kind == UInt32(kEventHotKeyReleased) {
                        hotKey.onRelease?()
                    }
                    return noErr
                }
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    /// Registers (or re-registers) the key combination. Returns false if another app already owns it.
    @discardableResult
    func register(_ combo: HotKeyCombo) -> Bool {
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x5644_4354), id: id) // "VDCT"
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            UInt32(combo.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    isolated deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
