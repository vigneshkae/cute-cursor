import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let icon = NSImage(size: NSSize(width: 1024, height: 1024))
icon.lockFocus()
NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.87, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210).fill()
let stem = NSBezierPath(); stem.lineCapStyle = .round; stem.lineWidth = 46
stem.move(to: NSPoint(x: 415, y: 610))
stem.curve(to: NSPoint(x: 740, y: 240), controlPoint1: NSPoint(x: 440, y: 440), controlPoint2: NSPoint(x: 640, y: 350))
NSColor(calibratedRed: 0.45, green: 0.58, blue: 0.36, alpha: 1).setStroke(); stem.stroke()
NSColor(calibratedRed: 0.57, green: 0.67, blue: 0.48, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 600, y: 370, width: 100, height: 170)).fill()
for index in 0..<6 {
    let petal = NSBezierPath(ovalIn: NSRect(x: -83, y: 0, width: 166, height: 245))
    var rotate = AffineTransform(); rotate.rotate(byDegrees: CGFloat(index) * 60)
    petal.transform(using: rotate)
    petal.transform(using: AffineTransform(translationByX: 420, byY: 610))
    NSColor(calibratedRed: 0.97, green: 0.82, blue: 0.41, alpha: 1).setFill(); petal.fill()
}
NSColor(calibratedRed: 0.81, green: 0.59, blue: 0.24, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 347, y: 537, width: 146, height: 146)).fill()
icon.unlockFocus()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
