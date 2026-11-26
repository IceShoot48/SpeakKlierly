import AppKit
import ApplicationServices

/// Types text into whatever app is frontmost by putting it on the clipboard and sending ⌘V.
/// Your previous clipboard contents are put back afterwards.
@MainActor
enum TextInserter {
    /// Whether macOS lets this app send keystrokes (System Settings › Privacy & Security › Accessibility).
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that sends the user to the Accessibility settings.
    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func insert(_ text: String, restoreClipboard: Bool) async {
        let pasteboard = NSPasteboard.general
        let savedItems = snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        // Give modifier keys from the hotkey a moment to be released.
        try? await Task.sleep(for: .milliseconds(120))
        sendPasteShortcut()

        guard restoreClipboard else { return }
        // Wait for the target app to read the clipboard before restoring it.
        try? await Task.sleep(for: .milliseconds(600))
        if pasteboard.changeCount == ourChangeCount {
            pasteboard.clearContents()
            if !savedItems.isEmpty { pasteboard.writeObjects(savedItems) }
        }
    }

    private static func sendPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Deep-copies the clipboard so it can be restored after pasting.
    private static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }
}
