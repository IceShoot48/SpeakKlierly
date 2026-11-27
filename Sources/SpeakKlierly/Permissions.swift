import AppKit
import AVFoundation
import ApplicationServices

/// The two macOS permissions SpeakKlierly needs, and helpers to ask for them one at a time.
@MainActor
enum Permissions {
    static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static var microphoneGranted: Bool { microphoneStatus == .authorized }
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    static var allGranted: Bool { microphoneGranted && accessibilityGranted }

    /// macOS only saves permissions reliably for an app opened from Applications. An app opened straight
    /// from Downloads runs from a temporary, randomized location ("App Translocation").
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    /// Shows the system microphone prompt. macOS only shows it once; after that, it can only be
    /// changed in System Settings, so we open that page instead.
    static func requestMicrophone() async {
        if microphoneStatus == .notDetermined {
            // A menu bar app isn't frontmost, and the prompt can end up hidden behind other windows.
            NSApplication.shared.activate()
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        } else if !microphoneGranted {
            open(.microphone)
        }
    }

    /// Adds SpeakKlierly to the Accessibility list (switched off) so the user only has to switch it on.
    /// macOS doesn't let apps switch it on themselves.
    ///
    /// The first time, macOS shows its own alert with an "Open System Settings" button. macOS may not
    /// show that alert again, so later requests open the Accessibility list directly.
    static func requestAccessibility() {
        let askedKey = "askedForAccessibility"
        NSApplication.shared.activate()
        if UserDefaults.standard.bool(forKey: askedKey) {
            open(.accessibility)
        } else {
            UserDefaults.standard.set(true, forKey: askedKey)
            TextInserter.requestAccessibilityPermission()
        }
    }

    static func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    enum Pane {
        case microphone, accessibility

        var url: URL {
            switch self {
            case .microphone:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
            case .accessibility:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            }
        }
    }

    static func open(_ pane: Pane) {
        NSWorkspace.shared.open(pane.url)
    }
}
