// Renders the SpeakKlierly app icon to a 1024×1024 PNG.
// Recreates Design/VoiceDictation icon.pdf as vector shapes: an orange microphone whose
// sound becomes lines of text, with an orange cursor where the next word lands.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

let navy = NSColor(red: 0.078, green: 0.125, blue: 0.231, alpha: 1)
let orange = NSColor(red: 0.98, green: 0.64, blue: 0.08, alpha: 1)

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let context = NSGraphicsContext.current?.cgContext else { return false }

    // macOS icon grid: an 824pt rounded square centered in the 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    /// Converts design coordinates (0...1 across the tile, measured top-down) to canvas points.
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: tile.minX + x * tile.width, y: tile.maxY - y * tile.height)
    }
    func length(_ value: CGFloat) -> CGFloat { value * tile.width }

    /// A horizontal pill from x1 to x2 centered on y.
    func pill(x1: CGFloat, x2: CGFloat, y: CGFloat, thickness: CGFloat, color: NSColor) {
        let t = length(thickness)
        let start = point(x1, y)
        let rect = CGRect(x: start.x, y: start.y - t / 2, width: length(x2 - x1), height: t)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: t / 2, cornerHeight: t / 2, transform: nil))
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    // Soft drop shadow under the tile.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    context.addPath(tilePath)
    context.setFillColor(navy.cgColor)
    context.fillPath()
    context.restoreGState()

    // Microphone capsule.
    let capsuleTop = point(0.281, 0.179)
    let capsuleRect = CGRect(x: capsuleTop.x, y: capsuleTop.y - length(0.384), width: length(0.220), height: length(0.384))
    context.addPath(CGPath(roundedRect: capsuleRect, cornerWidth: capsuleRect.width / 2, cornerHeight: capsuleRect.width / 2, transform: nil))
    context.setFillColor(orange.cgColor)
    context.fillPath()

    // Grille lines inside the capsule.
    for y in [0.292, 0.354, 0.417] as [CGFloat] {
        pill(x1: 0.333, x2: 0.448, y: y, thickness: 0.023, color: navy)
    }

    // White holder: a U-shaped arc, stem, and base.
    context.setStrokeColor(NSColor.white.cgColor)
    context.setLineWidth(length(0.039))
    context.setLineCap(.round)
    let arcCenter = point(0.390, 0.468)
    context.addArc(center: arcCenter, radius: length(0.189), startAngle: .pi, endAngle: 0, clockwise: false)
    context.strokePath()
    // Flat-ended stem so it meets the arc without a bump.
    context.setLineCap(.butt)
    context.setLineWidth(length(0.043))
    context.move(to: point(0.390, 0.650))
    context.addLine(to: point(0.390, 0.788))
    context.strokePath()
    pill(x1: 0.271, x2: 0.509, y: 0.788, thickness: 0.043, color: .white)

    // Lines of text, fading as they go down.
    pill(x1: 0.635, x2: 0.842, y: 0.333, thickness: 0.043, color: NSColor(white: 0.95, alpha: 1))
    pill(x1: 0.635, x2: 0.795, y: 0.433, thickness: 0.043, color: NSColor(red: 0.77, green: 0.78, blue: 0.82, alpha: 1))
    pill(x1: 0.635, x2: 0.823, y: 0.528, thickness: 0.043, color: NSColor(red: 0.57, green: 0.60, blue: 0.66, alpha: 1))
    pill(x1: 0.635, x2: 0.737, y: 0.634, thickness: 0.043, color: NSColor(red: 0.42, green: 0.45, blue: 0.53, alpha: 1))

    // Text cursor.
    let cursorTop = point(0.757, 0.589)
    let cursorWidth = length(0.018)
    let cursor = CGRect(x: cursorTop.x, y: cursorTop.y - length(0.097), width: cursorWidth, height: length(0.097))
    context.addPath(CGPath(roundedRect: cursor, cornerWidth: cursorWidth / 2, cornerHeight: cursorWidth / 2, transform: nil))
    context.setFillColor(orange.cgColor)
    context.fillPath()

    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Couldn't render icon")
}
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
