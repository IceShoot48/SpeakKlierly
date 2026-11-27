import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    let controller: DictationController
    /// Bumped every second so permission changes made in System Settings show up right away.
    @State private var permissionCheck = 0

    var body: some View {
        @Bindable var settings = controller.settings
        let _ = permissionCheck
        let needsSetup = !Permissions.allGranted || !Permissions.isInApplicationsFolder

        Form {
            if needsSetup {
                PermissionsSection(isSetup: true)
            }

            Section("Shortcut") {
                LabeledContent("Dictation hotkey") {
                    HotKeyRecorder(controller: controller)
                }
                if controller.hotKeyConflict {
                    Text("That shortcut is already used by another app. Pick a different one.")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Text("Tap to start and tap again to finish, or hold while you talk. Press Esc to cancel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Show recording indicator at bottom of screen", isOn: $settings.showIndicator)
                Toggle("Play start and stop sounds", isOn: $settings.playSounds)
                Toggle("Restore clipboard after inserting text", isOn: $settings.restoreClipboard)
                Toggle("Start SpeakKlierly automatically when I log in", isOn: $settings.launchAtLogin)
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            if !needsSetup {
                PermissionsSection(isSetup: false)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                permissionCheck &+= 1
            }
        }
    }
}

/// Microphone and Accessibility, with one button each and a short, friendly explanation.
/// Shown at the top as "Finish setting up" until everything is granted, then at the bottom as a status list.
private struct PermissionsSection: View {
    let isSetup: Bool

    var body: some View {
        let micGranted = Permissions.microphoneGranted
        let axGranted = Permissions.accessibilityGranted

        Section {
            if !Permissions.isInApplicationsFolder {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Move SpeakKlierly to Applications first", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.body.weight(.semibold))
                    Text("macOS won't save its permissions while it runs from Downloads. Quit, drag SpeakKlierly into your Applications folder, and open it from there.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Show in Finder") { Permissions.revealAppInFinder() }
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                    }
                }
                .padding(.vertical, 2)
            }

            PermissionRow(
                step: isSetup ? 1 : nil,
                title: "Microphone",
                detail: "So it can hear you while you dictate.",
                isGranted: micGranted,
                buttonTitle: Permissions.microphoneStatus == .notDetermined ? "Allow" : "Open Settings…"
            ) {
                Task { await Permissions.requestMicrophone() }
            }

            PermissionRow(
                step: isSetup ? 2 : nil,
                title: "Accessibility",
                detail: "So it can type the text into your apps.",
                isGranted: axGranted,
                buttonTitle: "Allow…"
            ) {
                Permissions.requestAccessibility()
            }

            if !axGranted {
                Text("In System Settings, switch SpeakKlierly on. Not in the list? Click **+** and choose it from Applications. Already on but not typing? Remove it with **−** and add it again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(isSetup ? "Finish setting up" : "Permissions")
        } footer: {
            if isSetup {
                Text("**Why this is safe:** SpeakKlierly only listens while your shortcut is active, turns speech into text right on your Mac, and only uses Accessibility to paste that text. Nothing is uploaded, and the code is open source.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct PermissionRow: View {
    let step: Int?
    let title: String
    let detail: String
    let isGranted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let step {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "\(step).circle")
                    .font(.title2)
                    .foregroundStyle(isGranted ? .green : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A button that, when clicked, captures the next key combination as the new hotkey.
private struct HotKeyRecorder: View {
    let controller: DictationController
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Type shortcut…" : controller.settings.hotKey.displayString)
                .frame(minWidth: 110)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        // Keep the current hotkey from firing while the user types the new one.
        controller.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording {
            isRecording = false
            controller.applyHotKey()
        }
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = Int(event.keyCode)

        // Plain Escape cancels recording.
        if keyCode == kVK_Escape && flags.isDisjoint(with: [.command, .option, .control, .shift]) {
            stopRecording()
            return
        }

        var modifiers = 0
        if flags.contains(.command) { modifiers |= cmdKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.shift) { modifiers |= shiftKey }

        // Require a modifier so ordinary typing isn't hijacked, except for function keys.
        let functionKeyName = Self.functionKeyNames[keyCode]
        guard modifiers != 0 || functionKeyName != nil else {
            NSSound.beep()
            return
        }

        controller.settings.hotKey = HotKeyCombo(
            keyCode: keyCode,
            carbonModifiers: modifiers,
            keyName: functionKeyName ?? Self.keyName(for: event)
        )
        stopRecording()
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            let character = event.characters(byApplyingModifiers: []) ?? event.charactersIgnoringModifiers ?? "?"
            return character.uppercased()
        }
    }

    private static let functionKeyNames: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]
}
