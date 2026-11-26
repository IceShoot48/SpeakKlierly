import Carbon.HIToolbox
import Foundation
import Observation
import ServiceManagement

/// A key plus Carbon modifier flags, e.g. ⌥Space.
struct HotKeyCombo: Codable, Equatable {
    var keyCode: Int
    var carbonModifiers: Int
    /// Human-readable key name captured when the shortcut was recorded ("Space", "D", "F5").
    var keyName: String

    static let optionSpace = HotKeyCombo(keyCode: kVK_Space, carbonModifiers: optionKey, keyName: "Space")

    var displayString: String {
        var result = ""
        if carbonModifiers & controlKey != 0 { result += "⌃" }
        if carbonModifiers & optionKey != 0 { result += "⌥" }
        if carbonModifiers & shiftKey != 0 { result += "⇧" }
        if carbonModifiers & cmdKey != 0 { result += "⌘" }
        return result + keyName
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var hotKey: HotKeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) { defaults.set(data, forKey: "hotKey") }
        }
    }

    var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: "playSounds") }
    }

    var showIndicator: Bool {
        didSet { defaults.set(showIndicator, forKey: "showIndicator") }
    }

    var restoreClipboard: Bool {
        didSet { defaults.set(restoreClipboard, forKey: "restoreClipboard") }
    }

    private(set) var launchAtLoginError: String?

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = error.localizedDescription
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    init() {
        defaults.register(defaults: [
            "playSounds": true,
            "showIndicator": true,
            "restoreClipboard": true,
        ])
        if let data = defaults.data(forKey: "hotKey"),
           let saved = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            hotKey = saved
        } else {
            hotKey = .optionSpace
        }
        playSounds = defaults.bool(forKey: "playSounds")
        showIndicator = defaults.bool(forKey: "showIndicator")
        restoreClipboard = defaults.bool(forKey: "restoreClipboard")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
