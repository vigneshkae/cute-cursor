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
        XCTAssertEqual(store.items.count, 3)
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

    func testInvalidSystemPackRejectedBeforeTouchingRegistry() {
        XCTAssertEqual(CSApplyCursors(nil, 0), -2)
        var definition = CSCursorDefinition(role: 99, image: nil, width: 32, height: 32, x: 1, y: 1)
        XCTAssertEqual(CSApplyCursors(&definition, 1), -2)
        XCTAssertFalse(CSHasAppliedCursors())
    }
}
