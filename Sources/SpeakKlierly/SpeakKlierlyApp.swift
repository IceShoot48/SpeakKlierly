import SwiftUI

@main
struct SpeakKlierlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: appDelegate.controller, showSettings: appDelegate.showSettings)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController(settings: AppSettings())
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            // Start automatically at login unless the user turns it off later.
            controller.settings.launchAtLogin = true
            showSettings()
        }
    }

    /// Opening the app again (from Applications, Spotlight, or the Dock) while it's
    /// already running shows Settings, so there's visible confirmation it's on.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller)))
            window.title = "SpeakKlierly Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        // Menu bar apps aren't frontmost by default, so bring the window forward.
        NSApplication.shared.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

private struct MenuContent: View {
    let controller: DictationController
    let showSettings: () -> Void

    var body: some View {
        Text(controller.state.statusText)

        if let error = controller.errorMessage {
            Text(error)
        }

        Divider()

        Button(controller.state == .listening ? "Stop & Insert" : "Start Dictation") {
            controller.toggle()
        }
        .disabled(controller.state == .transcribing)

        if controller.state == .listening {
            Button("Cancel") { controller.cancel() }
        }

        if !controller.lastTranscript.isEmpty {
            Button("Copy Last Transcript") { controller.copyLastTranscript() }
        }

        Divider()

        Text("Hotkey: \(controller.settings.hotKey.displayString) (tap to toggle, or hold to talk)")

        Button("Settings…", action: showSettings)
            .keyboardShortcut(",")

        Button("Quit SpeakKlierly") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private extension DictationController.State {
    var statusText: String {
        switch self {
        case .idle: "Ready"
        case .starting: "Starting…"
        case .listening: "Listening…"
        case .transcribing: "Transcribing…"
        }
    }
}
