<p align="center">
  <img src="docs/banner.svg" alt="SpeakKlierly: talk instead of type, in any Mac app" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-27%2B-161F3C?logo=apple&logoColor=white" alt="macOS 27+">
  <img src="https://img.shields.io/badge/Swift-6.2-F9A51A?logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/license-MIT-161F3C" alt="MIT license">
  <img src="https://img.shields.io/badge/price-free-F9A51A" alt="Free">
</p>

**SpeakKlierly** is a free, open-source dictation app for the Mac. Press a hotkey, say what you want to write, and clean, punctuated text appears wherever your cursor is: email, Slack, Notes, a code editor, a chat with an AI assistant, anything.

It lives quietly in your menu bar and does all of its speech recognition **on your Mac**. Your voice never leaves your computer, there's no account to create, and there's no subscription.

---

## How it works

<p align="center">
  <img src="docs/how-it-works.svg" alt="1. Press Option-Space. 2. Talk while a waveform shows it's listening. 3. Punctuated text is typed into your app." width="100%">
</p>

1. **Press <kbd>⌥ Option</kbd> + <kbd>Space</kbd>** in any app.
2. **Talk.** A small pill with a live waveform appears at the bottom of your screen, so you always know when you're being heard.
3. **Press the hotkey again.** Your words are transcribed and typed right where your cursor is.

Prefer push-to-talk? **Hold** the hotkey while you speak and let go when you're done. Changed your mind? Press <kbd>Esc</kbd> to cancel and nothing is typed.

## Why you'll like it

| | |
|---|---|
| 🎙️ **Works in every app** | If you can type there, you can dictate there. No plugins or per-app setup. |
| 🔒 **Private by design** | Uses Apple's on-device speech recognition. No audio is uploaded, and there are no servers, accounts or tracking. |
| ⚡ **Fast to start** | One shortcut from anywhere. The speech model is downloaded in advance, so dictation starts right away. |
| ✍️ **Clean, punctuated text** | Built for long-form writing like emails, messages, notes and prompts, with automatic punctuation. |
| 📋 **Respects your clipboard** | Text is pasted in for you, then your previous clipboard contents are put back. |
| 🎛️ **Yours to tweak** | Pick any shortcut, turn sounds and the on-screen indicator on or off, and launch at login. |
| 💸 **Free and open source** | MIT licensed. Read the code, change it, share it. |

## Features

- **Global hotkey** (<kbd>⌥ Space</kbd> by default, fully customizable, including F-keys)
- **Tap to toggle or hold to talk**, whichever feels natural
- **Floating recording indicator** with a live audio waveform that never steals focus
- **Start and stop sounds** so you can dictate without looking
- **Copy Last Transcript** from the menu bar, in case you need it again
- **Launch at login**, so it's always ready
- **Graceful fallbacks:** if typing permission isn't granted yet, your text is still copied to the clipboard and nothing is lost
- **Menu bar only:** no Dock icon and no windows in your way

## Requirements

- macOS 27 or later
- A microphone (built-in is fine)
- A system language supported by Apple's on-device dictation

## Install

SpeakKlierly is built from source using one script. You'll need Xcode (or the Xcode Command Line Tools) installed.

```bash
git clone https://github.com/IceShoot48/SpeakKlierly.git
cd SpeakKlierly
./build.sh install
```

This builds `SpeakKlierly.app`, copies it to `/Applications` and launches it. To build without installing, run `./build.sh` and find the app in `build/`.

### First launch

The first time it runs, SpeakKlierly opens its Settings window and asks for two permissions:

| Permission | Why it's needed |
|---|---|
| **Microphone** | To hear you while you're dictating, and only then. |
| **Accessibility** | To paste the finished text into the app you're using. |

You can check or change both at any time in **Settings → Permissions**, or in **System Settings → Privacy & Security**.

> **Tip:** If you have an Apple Development certificate, `build.sh` signs the app with it automatically, so macOS remembers your permissions across rebuilds.

## Settings

Click the SpeakKlierly icon in the menu bar and choose **Settings…** (or press <kbd>⌘ ,</kbd>).

- **Dictation hotkey:** click it, then press the new shortcut you want
- **Show recording indicator** at the bottom of the screen
- **Play start and stop sounds**
- **Restore clipboard** after inserting text
- **Start automatically when you log in**

## Privacy

SpeakKlierly listens to your microphone **only** while dictation is active. Speech recognition runs entirely on your Mac using Apple's built-in speech models. The app makes no network requests of its own and collects no data. Your settings are stored locally in macOS preferences.

## Project layout

```
Sources/SpeakKlierly/
├── SpeakKlierlyApp.swift      # Menu bar app and menu
├── DictationController.swift  # Ties the hotkey, transcription, indicator and typing together
├── Transcriber.swift          # On-device speech recognition (SpeechAnalyzer)
├── TextInserter.swift         # Pastes text into the frontmost app, restores the clipboard
├── HotKey.swift               # System-wide hotkey
├── RecordingOverlay.swift     # Floating waveform pill
├── SettingsView.swift         # Settings window
├── AppSettings.swift          # Saved preferences
└── MenuBarIcon.swift          # Menu bar glyph
Resources/                     # Info.plist and app icon
build.sh                       # Builds, signs and (optionally) installs the app
```

## Contributing

Bug reports, ideas and pull requests are welcome. Open an issue to talk about a change, or just send a PR.

## License

SpeakKlierly is free and open source under the [MIT License](LICENSE).

<p align="center">
  <img src="docs/icon-256.png" alt="SpeakKlierly icon" width="96"><br>
  <sub>Made for people who think faster than they type.</sub>
</p>
