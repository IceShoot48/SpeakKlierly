import AppKit

/// The menu bar glyph from Design/Menu bar icon.pdf: a solid mic with three text lines.
/// Drawn as a template image so macOS colors it for light and dark menu bars.
enum MenuBarIcon {
    static let image: NSImage = {
        // Design coordinates are fractions of the artboard, measured top-down.
        let bounds = CGRect(x: 0.155, y: 0.217, width: 0.64, height: 0.56)
        let scale: CGFloat = 16 / bounds.height
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)

        let image = NSImage(size: size, flipped: true) { _ in
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: (x - bounds.minX) * scale, y: (y - bounds.minY) * scale)
            }
            func pill(x1: CGFloat, x2: CGFloat, y: CGFloat) {
                let thickness = 0.054 * scale
                let start = point(x1, y)
                let rect = NSRect(x: start.x, y: start.y - thickness / 2, width: (x2 - x1) * scale, height: thickness)
                NSBezierPath(roundedRect: rect, xRadius: thickness / 2, yRadius: thickness / 2).fill()
            }

            NSColor.black.set()

            // Solid mic capsule.
            let capsuleOrigin = point(0.286, 0.227)
            let capsule = NSRect(x: capsuleOrigin.x, y: capsuleOrigin.y, width: 0.171 * scale, height: 0.301 * scale)
            NSBezierPath(roundedRect: capsule, xRadius: capsule.width / 2, yRadius: capsule.width / 2).fill()

            // U-shaped holder (lower half of a circle; y points down in this flipped image).
            let arc = NSBezierPath()
            arc.appendArc(withCenter: point(0.370, 0.462), radius: 0.131 * scale, startAngle: 0, endAngle: 180, clockwise: false)
            arc.lineWidth = 0.054 * scale
            arc.lineCapStyle = .round
            arc.stroke()

            // Stem and base.
            let stem = NSBezierPath()
            stem.move(to: point(0.370, 0.585))
            stem.line(to: point(0.370, 0.741))
            stem.lineWidth = 0.054 * scale
            stem.stroke()
            pill(x1: 0.272, x2: 0.469, y: 0.741)

            // Text lines.
            pill(x1: 0.558, x2: 0.785, y: 0.356)
            pill(x1: 0.558, x2: 0.743, y: 0.484)
            pill(x1: 0.558, x2: 0.669, y: 0.612)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "SpeakKlierly"
        return image
    }()
}
