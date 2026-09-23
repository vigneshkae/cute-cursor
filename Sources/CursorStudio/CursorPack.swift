import AppKit
import ImageIO
import UniformTypeIdentifiers

// Stable, platform-neutral names shared by exported packs and the future Windows app.
enum CursorRole: String, Codable, CaseIterable, Identifiable {
    case pointer, link, text, grab, grabbing, resizeHorizontal, resizeVertical
    case resizeDiagonalNWSE, resizeDiagonalNESW, crosshair, notAllowed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pointer: return "Pointer"
        case .link: return "Link"
        case .text: return "Text"
        case .grab: return "Grab"
        case .grabbing: return "Grabbing"
        case .resizeHorizontal: return "Resize ↔"
        case .resizeVertical: return "Resize ↕"
        case .resizeDiagonalNWSE: return "Resize ⤡"
        case .resizeDiagonalNESW: return "Resize ⤢"
        case .crosshair: return "Crosshair"
        case .notAllowed: return "Not allowed"
        }
    }
    var symbol: String {
        switch self {
        case .pointer: return "cursorarrow"
        case .link: return "hand.point.up.left"
        case .text: return "character.cursor.ibeam"
        case .grab: return "hand.raised"
        case .grabbing: return "hand.raised.fingers.spread"
        case .resizeHorizontal: return "arrow.left.and.right"
        case .resizeVertical: return "arrow.up.and.down"
        case .resizeDiagonalNWSE: return "arrow.up.left.and.arrow.down.right"
        case .resizeDiagonalNESW: return "arrow.up.right.and.arrow.down.left"
        case .crosshair: return "plus"
        case .notAllowed: return "nosign"
        }
    }
    var systemIndex: Int32 { Int32(Self.allCases.firstIndex(of: self)!) }

    // Asking AppKit for its native cursors initializes lazily registered slots.
    static func prepareSystemCursors() {
        let cursors: [NSCursor] = [.arrow, .pointingHand, .iBeam, .openHand, .closedHand,
                                   .resizeLeftRight, .resizeUpDown, .crosshair, .operationNotAllowed]
        for cursor in cursors { _ = cursor.image }
        if #available(macOS 15.0, *) {
            for position: NSCursor.FrameResizePosition in [.topLeft, .topRight, .left, .top] {
                _ = NSCursor.frameResize(position: position, directions: .all).image
            }
        }
    }
}

struct CursorPack: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    // Each pack owns its settings. Images can be shared with the library safely.
    var cursors: [String: CursorItem] = [:]
    subscript(role: CursorRole) -> CursorItem? {
        get { cursors[role.rawValue] }
        set { cursors[role.rawValue] = newValue }
    }
}

extension CursorItem {
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 &&
        UUID(uuidString: URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent) != nil &&
        fileName == URL(fileURLWithPath: fileName).lastPathComponent && fileName.hasSuffix(".png") &&
        size.isFinite && (16...64).contains(size) && hotspotX.isFinite && hotspotY.isFinite &&
        (0...1).contains(hotspotX) && (0...1).contains(hotspotY)
    }
}

struct PortablePack: Codable {
    static let fileExtension = "cutecursor"
    static let contentType = UTType(exportedAs: "com.cutecursor.pack", conformingTo: .data)
    var format = "CuteCursorPack"
    var version = 1
    var name: String
    var cursors: [Slot]
    struct Slot: Codable {
        var role: CursorRole
        var name: String
        var size: Double
        var hotspotX: Double
        var hotspotY: Double
        var png: Data
    }

    static func decode(_ data: Data) throws -> PortablePack {
        guard data.count <= 16 * 1024 * 1024 else { throw PackError.invalid("The pack exceeds 16 MB.") }
        let pack = try JSONDecoder().decode(Self.self, from: data)
        guard pack.format == "CuteCursorPack", pack.version == 1 else { throw PackError.invalid("This pack format or version is not supported.") }
        guard !pack.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, pack.name.count <= 80,
              !pack.cursors.isEmpty, pack.cursors.count <= CursorRole.allCases.count,
              Set(pack.cursors.map(\.role)).count == pack.cursors.count else { throw PackError.invalid("The pack has an invalid name or duplicate cursor roles.") }
        for slot in pack.cursors {
            guard !slot.name.isEmpty, slot.name.count <= 200, slot.size.isFinite, (16...64).contains(slot.size),
                  slot.hotspotX.isFinite, slot.hotspotY.isFinite, (0...1).contains(slot.hotspotX), (0...1).contains(slot.hotspotY),
                  slot.png.count <= 1024 * 1024, slot.png.starts(with: [137,80,78,71,13,10,26,10]),
                  let source = CGImageSourceCreateWithData(slot.png as CFData, nil), CGImageSourceGetCount(source) == 1,
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int,
                  (1...256).contains(width), (1...256).contains(height),
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw PackError.invalid("A cursor image or click-point setting is invalid.") }
        }
        return pack
    }
}

enum PackError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
