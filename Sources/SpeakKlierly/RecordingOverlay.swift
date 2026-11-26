import AppKit
import SwiftUI

/// The floating pill at the bottom-center of the screen that shows when you're being recorded,
/// similar to Wispr Flow's indicator. It never takes focus, so typing goes to your app as usual.
@MainActor
final class RecordingOverlay {
    private let panel: NSPanel

    init(controller: DictationController) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let hosting = NSHostingView(rootView: OverlayView(controller: controller))
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    func show() {
        positionOnActiveScreen()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Bottom-center of whichever screen the mouse is on, just above the Dock.
    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 24))
    }
}

private struct OverlayView: View {
    let controller: DictationController

    var body: some View {
        HStack(spacing: 10) {
            switch controller.state {
            case .listening:
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                WaveformView(levels: controller.levels)
            case .starting, .transcribing:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text(controller.state == .starting ? "Starting…" : "Transcribing…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Capsule().fill(.black.opacity(0.82)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: controller.state)
    }
}

/// Scrolling bars of recent microphone levels; newest on the right.
private struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 4 + CGFloat(levels[index]) * 18)
            }
        }
        .frame(height: 22)
        .animation(.linear(duration: 0.08), value: levels)
    }
}
