// Renders Resources/AppIcon.icns: green squircle + white bolt. Run: swift scripts/make-icon.swift
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.20, green: 0.86, blue: 0.60, alpha: 1),
                        NSColor(red: 0.02, green: 0.55, blue: 0.42, alpha: 1)])!.draw(in: path, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.46, weight: .black)
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: bolt.size, flipped: false) { r in
            bolt.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
        }
        let b = tinted.size
        tinted.draw(in: NSRect(x: (s - b.width) / 2, y: (s - b.height) / 2, width: b.width, height: b.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("wrote \(out.path)")
