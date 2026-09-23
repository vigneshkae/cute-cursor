import AppKit

// Original geometric artwork, drawn here; no system cursor images are bundled.
enum PackArtwork {
    static func image(for role: CursorRole) -> NSImage {
        if role == .pointer { return OriginalArtwork.image(0) }
        let image = NSImage(size: CGSize(width: 128, height: 128))
        image.lockFocus()
        defer { image.unlockFocus() }
        let purple = NSColor(calibratedRed: 0.46, green: 0.34, blue: 0.88, alpha: 1)
        let path = NSBezierPath(); path.lineCapStyle = .round; path.lineJoinStyle = .round
        func line(_ x: Double, _ y: Double, _ xx: Double, _ yy: Double) {
            path.move(to: NSPoint(x: x, y: y)); path.line(to: NSPoint(x: xx, y: yy))
        }
        switch role {
        case .text:
            line(64, 22, 64, 106); line(43, 22, 85, 22); line(43, 106, 85, 106)
        case .crosshair:
            line(64, 20, 64, 108); line(20, 64, 108, 64)
        case .notAllowed:
            path.appendOval(in: NSRect(x: 24, y: 24, width: 80, height: 80)); line(36, 92, 92, 36)
        case .resizeHorizontal, .resizeVertical, .resizeDiagonalNWSE, .resizeDiagonalNESW:
            line(22, 64, 106, 64); line(22, 64, 42, 84); line(22, 64, 42, 44)
            line(106, 64, 86, 84); line(106, 64, 86, 44)
            let angle: CGFloat = role == .resizeVertical ? 90 : role == .resizeDiagonalNWSE ? -45 : role == .resizeDiagonalNESW ? 45 : 0
            let transform = AffineTransform(translationByX: -64, byY: -64)
            path.transform(using: transform)
            var rotate = AffineTransform(); rotate.rotate(byDegrees: angle); path.transform(using: rotate)
            path.transform(using: AffineTransform(translationByX: 64, byY: 64))
        case .link, .grab, .grabbing:
            // A mitten silhouette with distinct finger positions for each action.
            path.move(to: NSPoint(x: 42, y: 25)); path.line(to: NSPoint(x: 23, y: 56))
            path.curve(to: NSPoint(x: 38, y: 65), controlPoint1: NSPoint(x: 16, y: 74), controlPoint2: NSPoint(x: 30, y: 77))
            path.line(to: NSPoint(x: 45, y: 56))
            if role == .grabbing {
                path.line(to: NSPoint(x: 45, y: 77)); path.curve(to: NSPoint(x: 100, y: 77), controlPoint1: NSPoint(x: 52, y: 92), controlPoint2: NSPoint(x: 94, y: 91))
            } else {
                path.line(to: NSPoint(x: 45, y: 104)); path.curve(to: NSPoint(x: 61, y: 104), controlPoint1: NSPoint(x: 45, y: 116), controlPoint2: NSPoint(x: 61, y: 116))
                path.line(to: NSPoint(x: 61, y: role == .grab ? 83 : 70))
                path.line(to: NSPoint(x: 68, y: role == .grab ? 103 : 78))
                path.line(to: NSPoint(x: 80, y: role == .grab ? 102 : 78))
                path.line(to: NSPoint(x: 85, y: 75)); path.line(to: NSPoint(x: 94, y: role == .grab ? 91 : 75))
                path.line(to: NSPoint(x: 103, y: 84))
            }
            path.line(to: NSPoint(x: 97, y: 43)); path.line(to: NSPoint(x: 85, y: 25)); path.close()
            purple.setFill(); path.fill(); NSColor.white.setStroke(); path.lineWidth = 6; path.stroke()
            return image
        case .pointer: break
        }
        NSColor.white.setStroke(); path.lineWidth = 14; path.stroke()
        purple.setStroke(); path.lineWidth = 8; path.stroke()
        return image
    }
}
