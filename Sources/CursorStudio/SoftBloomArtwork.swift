import AppKit

// User-supplied Soft Bloom artwork. Keep role filenames and click points together.
enum SoftBloomArtwork {
    static let packID = UUID(uuidString: "75E7AB00-30B1-4AFC-9459-82B7C9A8BD40")!
    static let green = NSColor(calibratedRed: 0.43, green: 0.56, blue: 0.35, alpha: 1)
    static let sage = NSColor(calibratedRed: 0.57, green: 0.67, blue: 0.48, alpha: 1)
    static let pointerPreview = (try? image(for: .pointer)) ?? NSImage(size: CGSize(width: 128, height: 128))

    static func hotspot(for role: CursorRole) -> CGPoint {
        switch role {
        case .pointer: return CGPoint(x: 0.43, y: 0.43)
        case .link: return CGPoint(x: 0.45, y: 0.125)
        case .grab, .grabbing: return CGPoint(x: 0.50, y: 0.58)
        default: return CGPoint(x: 0.49, y: 0.49)
        }
    }

    static func image(for role: CursorRole) throws -> NSImage {
        let suffix: String
        switch role {
        case .resizeHorizontal: suffix = "resize-horizontal"
        case .resizeVertical: suffix = "resize-vertical"
        case .resizeDiagonalNWSE: suffix = "resize-nwse"
        case .resizeDiagonalNESW: suffix = "resize-nesw"
        case .notAllowed: suffix = "not-allowed"
        default: suffix = role.rawValue
        }
        let bundle = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        guard let url = bundle.url(forResource: "soft-bloom-\(suffix)", withExtension: "png", subdirectory: "SoftBloom") else {
            throw PackError.invalid("The bundled Soft Bloom artwork is missing. Reinstall Cute Cursor to restore it.")
        }
        // Use the same validated transparent-image import path as user imports.
        return try ImageImporter.read(url).image
    }
}
