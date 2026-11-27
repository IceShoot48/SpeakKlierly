# Changelog

All notable changes to SpeakKlierly. Download any version from the [Releases page](https://github.com/IceShoot48/SpeakKlierly/releases).

## 0.3 (2026-11-27)

### Fixed
- **Works on macOS 26 (Tahoe) again.** SpeakKlierly previously required macOS 27 and wouldn't open on older systems ([#3](https://github.com/IceShoot48/SpeakKlierly/issues/3)). It now runs on macOS 26 and later.
  - On macOS 27, dictation works exactly as before.
  - On macOS 26, the app records from the microphone a different way, because the method it used before only exists on macOS 27.

### Known limits
- macOS 15 and earlier still aren't supported, because they don't include Apple's on-device speech engine that SpeakKlierly uses.

## 0.2 (2026-11-26)

### Added
- **Guided permission setup.** A short "Finish setting up" screen walks you through the Microphone and Accessibility permissions one at a time, with an **Allow** button for each and a brief note on why they're safe.
- The setup screen shows a check mark as soon as each permission is allowed. It reappears on launch until both are allowed.
- A warning if SpeakKlierly is opened from Downloads instead of Applications, where macOS won't save its permissions.

### Fixed
- Permission prompts could be missed, and SpeakKlierly sometimes didn't appear in System Settings' Accessibility list.

## 0.1 (2026-11-26)

- First release: press a hotkey, talk, and your words are typed into any app.
- On-device transcription with automatic punctuation, a floating waveform indicator, a customizable hotkey (tap or hold), and Esc to cancel.
- Restores your clipboard after pasting, offers Copy Last Transcript, and can start at login.
