import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CursorSystem
@testable import CursorStudio

final class CursorStudioTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testNonSquareCursorKeepsAspectRatioAndClickPoint() {
        let image = NSImage(size: CGSize(width: 200, height: 100))
        var item = CursorItem(id: UUID(), name: "Test", fileName: "test.png", size: 48, hotspotX: 0.5, hotspotY: 0.25)
        XCTAssertEqual(item.dimensions(for: image), CGSize(width: 48, height: 24))
        XCTAssertEqual(item.hotspot(for: image), CGPoint(x: 24, y: 6))
        item.hotspotX = 3; item.hotspotY = -1
        XCTAssertLessThan(item.hotspot(for: image).x, 48)
        XCTAssertEqual(item.hotspot(for: image).y, 0)
    }

    @MainActor
    func testSystemCursorReceivesNativeAndRetinaBitmapsInsteadOfFullArtwork() throws {
        let artwork = OriginalArtwork.image(0).cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let representations = try XCTUnwrap(CSCreatePointerImages(artwork, 24, 18))
        XCTAssertEqual(CFArrayGetCount(representations), 2)
        for index in 0..<2 {
            let image = unsafeBitCast(CFArrayGetValueAtIndex(representations, index), to: CGImage.self)
            XCTAssertEqual(image.width, 24 * (index + 1))
            XCTAssertEqual(image.height, 18 * (index + 1))
            XCTAssertEqual(image.alphaInfo, .premultipliedLast)
            XCTAssertEqual(NSBitmapImageRep(cgImage: image).colorAt(x: 0, y: 0)?.alphaComponent, 0)
        }
        XCTAssertNil(CSCreatePointerImages(artwork, .nan, 24))
        XCTAssertNil(CSCreatePointerImages(artwork, 0, 24))
        XCTAssertNil(CSCreatePointerImages(artwork, 128, 128))
    }

    @MainActor
    func testPNGImportPreservesTransparencyAndDownsamples() throws {
        let root = try temporaryDirectory()
        let url = root.appendingPathComponent("transparent.png")
        let context = CGContext(data: nil, width: 1024, height: 512, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 300, y: 100, width: 200, height: 200))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        let result = try ImageImporter.read(url)
        XCTAssertEqual(result.image.size, CGSize(width: 256, height: 128))
        XCTAssertEqual(result.frameCount, 1)
        let decoded = NSBitmapImageRep(data: result.png)!
        XCTAssertEqual(decoded.colorAt(x: 0, y: 0)!.alphaComponent, 0)
    }

    func testInvalidImportIsRejected() throws {
        let root = try temporaryDirectory()
        let url = root.appendingPathComponent("broken.png")
        try Data("not an image".utf8).write(to: url)
        XCTAssertThrowsError(try ImageImporter.read(url))
        XCTAssertThrowsError(try ImageImporter.read(root.appendingPathComponent("unsupported.ani")))
        let big = root.appendingPathComponent("too-big.png")
        try Data(count: 16 * 1024 * 1024 + 1).write(to: big)
        XCTAssertThrowsError(try ImageImporter.read(big)) { error in
            guard case CursorImportError.tooLarge = error else { return XCTFail("Expected size guard") }
        }
    }

    @MainActor
    func testAnimatedGIFFlattensToFirstFrameAndExplainsIt() throws {
        let root = try temporaryDirectory()
        let url = root.appendingPathComponent("animated.gif")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 2, nil)!
        for kind in [0, 1] {
            let image = OriginalArtwork.image(kind)
            CGImageDestinationAddImage(destination, image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, nil)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let imported = try ImageImporter.read(url)
        XCTAssertEqual(imported.frameCount, 2)
        XCTAssertEqual(CGImageSourceGetCount(CGImageSourceCreateWithData(imported.png as CFData, nil)!), 1)
        let store = CursorStore(directory: root.appendingPathComponent("Library"))
        store.importFiles([url])
        XCTAssertNil(store.error)
        XCTAssertEqual(store.selected?.sourceNote, "First frame · GIF")
        XCTAssertTrue(store.notice?.contains("first frame") == true)
    }

    @MainActor
    func testBatchImportKeepsGoodImagesAndReportsBadOnes() throws {
        let root = try temporaryDirectory()
        let valid = root.appendingPathComponent("good.png")
        try OriginalArtwork.png(OriginalArtwork.image(2)).write(to: valid)
        let invalid = root.appendingPathComponent("bad.png")
        try Data("bad".utf8).write(to: invalid)
        let store = CursorStore(directory: root.appendingPathComponent("Library"))
        store.importFiles([invalid, valid])
        XCTAssertEqual(store.items.count, 4)
        XCTAssertEqual(store.selected?.name, "good")
        XCTAssertTrue(store.error?.contains("bad.png") == true)
    }

    @MainActor
    func testImportEditReloadAndDeleteKeepOriginalSafe() throws {
        let root = try temporaryDirectory()
        let library = root.appendingPathComponent("Library")
        let url = root.appendingPathComponent("my-ghost.png")
        try OriginalArtwork.png(OriginalArtwork.image(1)).write(to: url)
        let store = CursorStore(directory: library)
        XCTAssertEqual(store.items.count, 3)
        store.importFiles([url])
        XCTAssertNil(store.error)
        XCTAssertEqual(store.items.count, 4)
        let id = store.selectedID
        store.update { $0.name = "My custom ghost"; $0.size = 45; $0.isFavorite = true; $0.hotspotX = 0.42 }
        let restored = CursorStore(directory: library)
        restored.selectedID = id
        XCTAssertEqual(restored.selected?.name, "My custom ghost")
        XCTAssertEqual(restored.selected?.size, 45)
        XCTAssertEqual(restored.selected?.hotspotX, 0.42)
        XCTAssertEqual(restored.selected?.isFavorite, true)
        XCTAssertNotNil(restored.image(for: restored.selected!))
        restored.deleteSelected()
        XCTAssertNil(restored.error)
        XCTAssertEqual(CursorStore(directory: library).items.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testCorruptManifestIsNotOverwritten() throws {
        let root = try temporaryDirectory()
        let url = root.appendingPathComponent("library.json")
        let data = Data("broken manifest".utf8)
        try data.write(to: url)
        let store = CursorStore(directory: root)
        XCTAssertNotNil(store.error)
        XCTAssertThrowsError(try store.persist())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
