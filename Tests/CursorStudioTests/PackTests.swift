import XCTest
import AppKit
import CursorSystem
@testable import CursorStudio

final class PackTests: XCTestCase {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testFullPackRoundTripPreservesEveryRoleAndSetting() throws {
        let root = try temporaryDirectory()
        let store = CursorStore(directory: root.appendingPathComponent("Source"))
        XCTAssertNil(store.error)
        XCTAssertEqual(store.packs.first?.cursors.count, 11)
        store.packMode = true; store.selectedRole = .link
        store.update { $0.size = 47; $0.hotspotX = 0.25; $0.hotspotY = 0.15 }
        let pack = try XCTUnwrap(store.selectedPack)
        let url = root.appendingPathComponent("pack.cutecursor")
        try store.portablePack(pack).write(to: url)
        let destination = CursorStore(directory: root.appendingPathComponent("Destination"))
        try destination.importPack(url)
        XCTAssertEqual(destination.selectedPack?.cursors.count, 11)
        XCTAssertEqual(destination.selected?.name, "Pointer")
        for role in CursorRole.allCases {
            let a = try XCTUnwrap(pack[role]), b = try XCTUnwrap(destination.selectedPack?[role])
            XCTAssertNotEqual(a.id, b.id)
            XCTAssertEqual(a.size, b.size); XCTAssertEqual(a.hotspotX, b.hotspotX); XCTAssertEqual(a.hotspotY, b.hotspotY)
            XCTAssertEqual(try Data(contentsOf: store.directory.appendingPathComponent(a.fileName)),
                           try Data(contentsOf: destination.directory.appendingPathComponent(b.fileName)))
        }
        let reloaded = CursorStore(directory: destination.directory)
        XCTAssertEqual(reloaded.packs, destination.packs)
    }

    @MainActor
    func testPackEditsAreIndependentAndSharedImageSurvivesLibraryDeletion() throws {
        let store = CursorStore(directory: try temporaryDirectory())
        let original = try XCTUnwrap(store.items.first)
        store.createPack(); store.assign(original, to: .pointer)
        store.update { $0.size = 61; $0.hotspotX = 0.8 }
        XCTAssertEqual(store.items.first, original)
        XCTAssertEqual(store.selected?.size, 61)
        store.packMode = false; store.selectedID = original.id; store.deleteSelected()
        XCTAssertNil(store.error)
        store.packMode = true
        XCTAssertNotNil(store.selected.flatMap(store.image))
        XCTAssertNoThrow(try store.portablePack(XCTUnwrap(store.selectedPack)))
    }

    @MainActor
    func testInvalidPackDoesNotPartiallyImportOrWriteFiles() throws {
        let root = try temporaryDirectory(); let library = root.appendingPathComponent("Library")
        let store = CursorStore(directory: library)
        var pack = try PortablePack.decode(store.portablePack(XCTUnwrap(store.selectedPack)))
        pack.cursors[1].png = Data("not png".utf8)
        let url = root.appendingPathComponent("bad.cutecursor")
        try JSONEncoder().encode(pack).write(to: url)
        let before = try FileManager.default.contentsOfDirectory(atPath: library.path)
        XCTAssertThrowsError(try store.importPack(url))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.path).sorted(), before.sorted())
        XCTAssertEqual(store.packs.count, 1)
    }

    @MainActor
    func testDuplicateRolesUnknownVersionAndOutOfRangeHotspotsAreRejected() throws {
        let store = CursorStore(directory: try temporaryDirectory())
        let valid = try PortablePack.decode(store.portablePack(XCTUnwrap(store.selectedPack)))
        var invalid = valid; invalid.cursors[1].role = invalid.cursors[0].role
        XCTAssertThrowsError(try PortablePack.decode(JSONEncoder().encode(invalid)))
        invalid = valid; invalid.version = 99
        XCTAssertThrowsError(try PortablePack.decode(JSONEncoder().encode(invalid)))
        invalid = valid; invalid.cursors[0].hotspotX = -0.2
        XCTAssertThrowsError(try PortablePack.decode(JSONEncoder().encode(invalid)))
        invalid = valid; invalid.cursors = []
        XCTAssertThrowsError(try PortablePack.decode(JSONEncoder().encode(invalid)))
    }

    @MainActor
    func testCorruptPackLibraryPreservesBothManifests() throws {
        let root = try temporaryDirectory(); let store = CursorStore(directory: root)
        let library = try Data(contentsOf: root.appendingPathComponent("library.json"))
        let broken = Data("broken packs".utf8)
        try broken.write(to: root.appendingPathComponent("packs.json"))
        let loaded = CursorStore(directory: root)
        XCTAssertNotNil(loaded.error)
        loaded.createPack()
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("packs.json")), broken)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("library.json")), library)
        XCTAssertEqual(loaded.items, store.items)
    }

    @MainActor
    func testRemovingSlotPersistsAsOriginalWithoutChangingLibrary() throws {
        let store = CursorStore(directory: try temporaryDirectory())
        store.packMode = true; store.selectedRole = .link
        store.assign(nil, to: .link)
        XCTAssertNil(store.selected)
        XCTAssertEqual(store.selectedPack?.cursors.count, 10)
        let decoded = try PortablePack.decode(store.portablePack(XCTUnwrap(store.selectedPack)))
        XCTAssertFalse(decoded.cursors.contains { $0.role == .link })
        XCTAssertEqual(store.items.count, 20)
    }

    @MainActor
    func testMissingLibraryImageCanBeRemoved() throws {
        let store = CursorStore(directory: try temporaryDirectory())
        let item = try XCTUnwrap(store.selected)
        try FileManager.default.removeItem(at: store.directory.appendingPathComponent(item.fileName))
        store.deleteSelected()
        XCTAssertNil(store.error)
        XCTAssertFalse(store.items.contains { $0.id == item.id })
    }

    @MainActor
    func testSoftBloomDefaultHasAllRolesAt40WithTransparentArtwork() throws {
        let store = CursorStore(directory: try temporaryDirectory())
        let pack = try XCTUnwrap(store.selectedPack)
        XCTAssertEqual(pack.name, "Soft Bloom")
        XCTAssertEqual(pack.id, SoftBloomArtwork.packID)
        let portable = try PortablePack.decode(store.portablePack(pack))
        XCTAssertEqual(Set(portable.cursors.map(\.role)), Set(CursorRole.allCases))
        for slot in portable.cursors {
            XCTAssertEqual(slot.size, 40)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: slot.png))
            XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
            let x = min(bitmap.pixelsWide - 1, Int(slot.hotspotX * Double(bitmap.pixelsWide)))
            let y = min(bitmap.pixelsHigh - 1, Int(slot.hotspotY * Double(bitmap.pixelsHigh)))
            XCTAssertGreaterThan(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0, 0.5, "Click point must land on \(slot.role) artwork")
        }
    }

    @MainActor
    func testSoftBloomMigrationPreservesExistingPacksAndUserChanges() throws {
        let root = try temporaryDirectory()
        let original = CursorStore(directory: root)
        original.createPack(); original.renamePack("My existing flowers")
        original.assign(original.items[0], to: .pointer)
        original.update { $0.size = 51 }
        let existing = try XCTUnwrap(original.selectedPack)
        // Model a library from before the bundled-pack receipt existed.
        try JSONEncoder().encode([existing]).write(to: root.appendingPathComponent("packs.json"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("bundled-packs.json"))
        let upgraded = CursorStore(directory: root)
        XCTAssertNil(upgraded.error)
        XCTAssertEqual(upgraded.packs.count, 2)
        XCTAssertEqual(upgraded.packs.last, existing)
        upgraded.packMode = true
        upgraded.renamePack("My Soft Bloom")
        upgraded.update { $0.size = 46 }
        let renamed = try XCTUnwrap(upgraded.selectedPack)
        let reloaded = CursorStore(directory: root)
        XCTAssertEqual(reloaded.selectedPack, renamed)
        XCTAssertEqual(reloaded.packs.count, 2)
        reloaded.deletePack()
        let afterDeletion = CursorStore(directory: root)
        XCTAssertEqual(afterDeletion.packs, [existing], "Do not reinstall a deliberately deleted default pack")
    }

    func testInvalidSystemPackRejectedBeforeTouchingRegistry() {
        XCTAssertEqual(CSApplyCursors(nil, 0), -2)
        var definition = CSCursorDefinition(role: 99, image: nil, width: 32, height: 32, x: 1, y: 1)
        XCTAssertEqual(CSApplyCursors(&definition, 1), -2)
        XCTAssertFalse(CSHasAppliedCursors())
    }
}
