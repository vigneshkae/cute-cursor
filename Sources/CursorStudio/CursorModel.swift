import AppKit
import ImageIO
import UniformTypeIdentifiers

struct CursorItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var fileName: String
    var size: Double = 32
    var hotspotX: Double = 0.1
    var hotspotY: Double = 0.1
    var isFavorite: Bool = false
    var sourceNote: String = "Imported image"

    func dimensions(for image: NSImage) -> CGSize {
        let ratio = max(image.size.width, image.size.height)
        guard ratio > 0 else { return CGSize(width: size, height: size) }
        return CGSize(width: size * image.size.width / ratio, height: size * image.size.height / ratio)
    }

    func hotspot(for image: NSImage) -> CGPoint {
        let dimensions = dimensions(for: image)
        return CGPoint(x: min(max(hotspotX, 0), 0.999) * dimensions.width,
                       y: min(max(hotspotY, 0), 0.999) * dimensions.height)
    }

    func cursor(for image: NSImage) -> NSCursor {
        let copy = image.copy() as! NSImage
        copy.size = dimensions(for: image)
        return NSCursor(image: copy, hotSpot: hotspot(for: image))
    }
}

enum CursorImportError: LocalizedError {
    case tooLarge, unreadable, invalidDimensions, unsupported
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "This file is too large. Choose an image under 16 MB."
        case .unreadable: return "This image could not be read. Try exporting it as a PNG."
        case .invalidDimensions: return "Choose an image between 1 and 16,384 pixels on each side."
        case .unsupported: return "This file format isn’t supported. Try PNG, JPEG, WebP, HEIC, TIFF, GIF, or a static CUR file."
        }
    }
}

struct ImportedImage {
    let png: Data
    let image: NSImage
    let frameCount: Int
    let hotspot: CGPoint?
}

enum ImageImporter {
    static let extensions = ["png", "jpg", "jpeg", "webp", "heic", "heif", "tif", "tiff", "gif", "cur", "ico", "bmp"]

    static func read(_ url: URL) throws -> ImportedImage {
        guard extensions.contains(url.pathExtension.lowercased()) else { throw CursorImportError.unsupported }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let count = attributes[.size] as? NSNumber, count.intValue > 16 * 1024 * 1024 { throw CursorImportError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= 16 * 1024 * 1024 else { throw CursorImportError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { throw CursorImportError.unreadable }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard (1...16384).contains(width), (1...16384).contains(height) else { throw CursorImportError.invalidDimensions }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CursorImportError.unreadable }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CursorImportError.unreadable }
        // CUR stores the first entry's click point in little-endian words.
        var hotspot: CGPoint?
        if url.pathExtension.lowercased() == "cur", data.count >= 22, data[2] == 2, data[3] == 0 {
            let x = Int(data[10]) | Int(data[11]) << 8
            let y = Int(data[12]) | Int(data[13]) << 8
            hotspot = CGPoint(x: min(Double(x) / Double(width), 0.999), y: min(Double(y) / Double(height), 0.999))
        }
        return ImportedImage(png: png, image: NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height)),
                             frameCount: CGImageSourceGetCount(source), hotspot: hotspot)
    }
}

enum OriginalArtwork {
    static func image(_ kind: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 128, height: 128))
        image.lockFocus()
        let purple = NSColor(calibratedRed: 0.46, green: 0.34, blue: 0.88, alpha: 1)
        if kind == 0 {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 28, y: 113))
            path.line(to: NSPoint(x: 101, y: 57))
            path.line(to: NSPoint(x: 68, y: 50))
            path.line(to: NSPoint(x: 53, y: 18))
            path.close()
            purple.setFill(); path.fill()
            NSColor.white.setStroke(); path.lineWidth = 6; path.lineJoinStyle = .round; path.stroke()
        } else if kind == 1 {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 28, y: 25))
            path.line(to: NSPoint(x: 28, y: 70))
            path.curve(to: NSPoint(x: 100, y: 70), controlPoint1: NSPoint(x: 28, y: 119), controlPoint2: NSPoint(x: 100, y: 119))
            path.line(to: NSPoint(x: 100, y: 25))
            path.line(to: NSPoint(x: 82, y: 36)); path.line(to: NSPoint(x: 64, y: 24))
            path.line(to: NSPoint(x: 46, y: 36)); path.close()
            NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.57, alpha: 1).setFill(); path.fill()
            NSColor(calibratedWhite: 0.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 46, y: 66, width: 7, height: 13)).fill()
            NSBezierPath(ovalIn: NSRect(x: 74, y: 66, width: 7, height: 13)).fill()
            let smile = NSBezierPath(); smile.move(to: NSPoint(x: 57, y: 53))
            smile.curve(to: NSPoint(x: 72, y: 53), controlPoint1: NSPoint(x: 61, y: 47), controlPoint2: NSPoint(x: 68, y: 47))
            NSColor(calibratedWhite: 0.2, alpha: 1).setStroke(); smile.lineWidth = 3; smile.stroke()
        } else {
            NSColor(calibratedRed: 0.72, green: 0.72, blue: 0.97, alpha: 1).setFill()
            for index in 0..<6 {
                let angle = Double(index) * .pi / 3
                NSBezierPath(ovalIn: NSRect(x: 43 + cos(angle) * 28, y: 43 + sin(angle) * 28, width: 42, height: 42)).fill()
            }
            NSColor(calibratedRed: 1, green: 0.84, blue: 0.38, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 47, y: 47, width: 34, height: 34)).fill()
        }
        image.unlockFocus()
        return image
    }

    static func png(_ image: NSImage) -> Data {
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
    }
}
