import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let icon = NSImage(size: NSSize(width: 1024, height: 1024))
icon.lockFocus()
NSColor(calibratedRed: 0.43, green: 0.32, blue: 0.78, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210).fill()
let path = NSBezierPath()
path.move(to: NSPoint(x: 306, y: 799))
path.line(to: NSPoint(x: 766, y: 446))
path.line(to: NSPoint(x: 552, y: 405))
path.line(to: NSPoint(x: 447, y: 191))
path.close()
NSColor.white.setFill(); path.fill()
NSColor(calibratedRed: 1, green: 0.84, blue: 0.56, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 717, y: 724, width: 95, height: 95)).fill()
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
