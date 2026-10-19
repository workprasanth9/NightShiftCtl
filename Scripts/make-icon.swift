// Renders the app icon to a 1024x1024 PNG.
// Usage: swift Scripts/make-icon.swift App/AppIcon-1024.png
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: rounded square, dusk gradient from deep indigo to warm amber.
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.99, green: 0.62, blue: 0.27, alpha: 1),
    NSColor(calibratedRed: 0.62, green: 0.29, blue: 0.55, alpha: 1),
    NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.36, alpha: 1),
    NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.20, alpha: 1),
], atLocations: [0.0, 0.35, 0.72, 1.0], colorSpace: .deviceRGB)!
gradient.draw(in: shape, angle: 90)

// Crescent moon.
let moonCenter = NSPoint(x: size * 0.47, y: size * 0.55)
let moonRadius: CGFloat = 230
let moon = NSBezierPath(ovalIn: NSRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius,
                                       width: moonRadius * 2, height: moonRadius * 2))
NSGraphicsContext.current?.saveGraphicsState()
let cut = NSBezierPath(rect: rect)
cut.appendOval(in: NSRect(x: moonCenter.x - moonRadius + 120, y: moonCenter.y - moonRadius + 80,
                          width: moonRadius * 2, height: moonRadius * 2))
cut.windingRule = .evenOdd
cut.addClip()
NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.75, alpha: 1).setFill()
moon.fill()
NSGraphicsContext.current?.restoreGraphicsState()

// Stars.
func star(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4 + .pi / 2
        let radius = i % 2 == 0 ? r : r * 0.32
        let p = NSPoint(x: x + cos(angle) * radius, y: y + sin(angle) * radius)
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    NSColor(calibratedWhite: 1, alpha: 0.95).setFill()
    path.fill()
}
star(size * 0.70, size * 0.70, 62)
star(size * 0.78, size * 0.52, 36)
star(size * 0.62, size * 0.82, 26)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
