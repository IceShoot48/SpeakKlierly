import AppKit
import AVFoundation
import Carbon.HIToolbox
import Observation

/// Ties the hotkey, microphone transcription, on-screen indicator, and text insertion together.
///
/// Hotkey behavior (⌥Space by default):
/// - Tap once to start, tap again to stop and insert the text.
/// - Or hold it down while you talk; releasing stops and inserts.
/// - Press Escape while listening to cancel.
@MainActor
@Observable
final class DictationController {
    enum State: Equatable {
        case idle
        case starting
        case listening
        case transcribing
    }

    private(set) var state: State = .idle {
        didSet { stateChanged() }
    }
    private(set) var lastTranscript = ""
    private(set) var errorMessage: String?
    /// Recent microphone levels (0...1) for the waveform, oldest first.
    private(set) var levels = [Float](repeating: 0, count: DictationController.levelCount)
    private(set) var hotKeyConflict = false

    let settings: AppSettings
    /// Called when a permission is missing, so the app can show the setup window.
    @ObservationIgnored var onNeedsSetup: (() -> Void)?

    private static let levelCount = 14
    /// Holding the hotkey longer than this counts as push-to-talk rather than a tap.
    private let holdThreshold: Duration = .milliseconds(400)

    private let transcriber = Transcriber()
    private let hotKey = HotKey(id: 1)
    private let cancelKey = HotKey(id: 2)
    @ObservationIgnored private var overlay: RecordingOverlay?
    private var meterTask: Task<Void, Never>?
    private var pressedAt: ContinuousClock.Instant?
    private var stopRequestedWhileStarting = false

    init(settings: AppSettings) {
        self.settings = settings
        hotKey.onPress = { [weak self] in self?.hotKeyPressed() }
        hotKey.onRelease = { [weak self] in self?.hotKeyReleased() }
        cancelKey.onPress = { [weak self] in self?.cancel() }
        applyHotKey()
        overlay = RecordingOverlay(controller: self)

        Task { await prepareSpeechModel() }
    }

    /// Registers the hotkey from settings. Call after the user records a new shortcut.
    func applyHotKey() {
        hotKeyConflict = !hotKey.register(settings.hotKey)
    }

    /// Temporarily disables the hotkey, e.g. while recording a new one in Settings.
    func suspendHotKey() {
        hotKey.unregister()
    }

    func toggle() {
        switch state {
        case .idle: startListening()
        case .starting: stopRequestedWhileStarting = true
        case .listening: stopAndInsert()
        case .transcribing: break
        }
    }

    func cancel() {
        guard state == .listening || state == .starting else { return }
        Task {
            await transcriber.cancel()
            state = .idle
            play("Bottle")
        }
    }

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
    }

    // MARK: - Hotkey

    private func hotKeyPressed() {
        pressedAt = .now
        toggle()
    }

    private func hotKeyReleased() {
        guard let pressedAt, ContinuousClock.now - pressedAt >= holdThreshold else { return }
        self.pressedAt = nil
        // A long hold means push-to-talk: stop as soon as the key comes up.
        switch state {
        case .starting: stopRequestedWhileStarting = true
        case .listening: stopAndInsert()
        default: break
        }
    }

    // MARK: - Dictation

    private func startListening() {
        switch Permissions.microphoneStatus {
        case .authorized:
            break
        case .notDetermined:
            // First use: ask now, and start listening if the user allows it.
            Task {
                await Permissions.requestMicrophone()
                if Permissions.microphoneGranted { startListening() }
            }
            return
        default:
            errorMessage = "Microphone access is off. Turn it on in SpeakKlierly Settings."
            onNeedsSetup?()
            return
        }
        state = .starting
        errorMessage = nil
        stopRequestedWhileStarting = false

        Task {
            do {
                try await transcriber.start()
                state = .listening
                play("Tink")
                if stopRequestedWhileStarting { stopAndInsert() }
            } catch {
                state = .idle
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopAndInsert() {
        state = .transcribing
        play("Pop")

        Task {
            do {
                let text = try await transcriber.stop()
                state = .idle
                guard !text.isEmpty else { return }
                lastTranscript = text
                if TextInserter.hasAccessibilityPermission {
                    await TextInserter.insert(text, restoreClipboard: settings.restoreClipboard)
                } else {
                    // Without Accessibility we can't paste, but the text is still on the clipboard.
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    errorMessage = "Copied to clipboard. Allow Accessibility in Settings so text can be typed for you."
                    onNeedsSetup?()
                }
            } catch {
                state = .idle
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Indicator

    private func stateChanged() {
        if state == .idle {
            overlay?.hide()
        } else if settings.showIndicator {
            overlay?.show()
        }

        // Escape cancels only while we're listening, so it isn't stolen from other apps otherwise.
        if state == .listening || state == .starting {
            cancelKey.register(HotKeyCombo(keyCode: kVK_Escape, carbonModifiers: 0, keyName: "Esc"))
        } else {
            cancelKey.unregister()
        }

        if state == .listening {
            startMetering()
        } else {
            meterTask?.cancel()
            meterTask = nil
            levels = Array(repeating: 0, count: Self.levelCount)
        }
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                var updated = levels
                updated.removeFirst()
                updated.append(transcriber.currentLevel())
                levels = updated
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func play(_ sound: String) {
        guard settings.playSounds else { return }
        NSSound(named: sound)?.play()
    }

    // MARK: - Speech model

    /// Permissions are asked for one at a time from the Settings window (see `Permissions`),
    /// not all at once at launch, where a menu bar app's prompts are easy to miss.
    private func prepareSpeechModel() async {
        // Fetch the on-device speech model up front so the first dictation starts quickly.
        do {
            try await transcriber.prepareAssets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
