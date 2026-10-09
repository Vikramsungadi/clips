// Draws the 1024×1024 app icon: a paperclip on a blue–purple rounded square.
// Usage: makeicon <output.png>
import Cocoa

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let tile = NSBezierPath(roundedRect: bounds.insetBy(dx: 100, dy: 100), xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(srgbRed: 0.33, green: 0.47, blue: 1.0, alpha: 1),
                    NSColor(srgbRed: 0.58, green: 0.32, blue: 0.95, alpha: 1)])!.draw(in: tile, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let clip = NSImage(systemSymbolName: "paperclip", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let s = clip.size
    clip.draw(in: NSRect(x: (CGFloat(size) - s.width) / 2, y: (CGFloat(size) - s.height) / 2, width: s.width, height: s.height))
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
