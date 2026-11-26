# SpeakKlierly

A free, open-source macOS menu bar dictation app (Swift 6.2 / SwiftUI, macOS 27+). Press a hotkey (⌥Space by default), talk, and the text is transcribed on-device with Apple's SpeechAnalyzer and pasted into the frontmost app.

## Project boundaries

- Everything for this app lives in this folder. Do not create or edit files in the parent `Claude Projects` folder or in sibling project folders.
- Scratch files go in the session scratchpad, not here and not in the parent folder.

## Build and run

- `./build.sh` builds `build/SpeakKlierly.app` (release build, signed with the Apple Development certificate if one is available, otherwise ad-hoc).
- `./build.sh install` also copies it to `/Applications` and launches it.
- `.build/` and `build/` are build output and are git-ignored.

## Repo and releases

- GitHub: `IceShoot48/SpeakKlierly`, **private** until the owner decides to make it public.
- Commits use the GitHub noreply email set in this repo's local git config.
- Releases: build, then `ditto -c -k --keepParent build/SpeakKlierly.app build/SpeakKlierly-<version>.zip`, then `gh release create v<version>` with the zip. Bump `CFBundleShortVersionString` in `Resources/Info.plist` first.
- The app is not notarized, so the README tells downloaders to use **Open Anyway**.

## Code map

- `Sources/SpeakKlierly/DictationController.swift`: ties the hotkey, transcription, overlay and text insertion together.
- `Transcriber.swift`: on-device speech recognition.
- `TextInserter.swift`: clipboard paste via ⌘V and clipboard restore (needs Accessibility permission).
- `HotKey.swift`: Carbon global hotkey. `RecordingOverlay.swift`: the waveform pill. `SettingsView.swift` / `AppSettings.swift`: preferences.
- `docs/`: README graphics. `Design/`: source icon PDFs. `scripts/make-icon.swift`: icon generator.
