import XCTest
import AppKit
@testable import CursorStudio

final class CollectionTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @MainActor
    func testFreshCollectionAndNewImportsUse40() throws {
        let root = try directory()
        let store = CursorStore(directory: root.appendingPathComponent("Library"))
        XCTAssertNil(store.error)
        XCTAssertEqual(store.items.count, 20)
        XCTAssertEqual(Set(store.items.map(\.name)).count, 20)
        XCTAssertTrue(store.items.allSatisfy { $0.size == 40 && $0.isValid })
        for item in store.items {
            let image = try XCTUnwrap(store.image(for: item))
            XCTAssertEqual(max(item.dimensions(for: image).width, item.dimensions(for: image).height), 40, accuracy: 0.001)
        }
        let source = root.appendingPathComponent("new.png")
        try OriginalArtwork.png(OriginalArtwork.image(1)).write(to: source)
        store.importFiles([source])
        XCTAssertEqual(store.selected?.size, 40)
        XCTAssertEqual(store.packs.first?.cursors.count, 11)
        XCTAssertTrue(store.packs[0].cursors.values.allSatisfy { $0.size == 40 })
    }

    @MainActor
    func testCollectionEditsAndDeletionSurviveReload() throws {
        let root = try directory()
        let store = CursorStore(directory: root)
        let editedID = try XCTUnwrap(store.selectedID)
        store.update { $0.name = "My swimmer"; $0.size = 51; $0.isFavorite = true }
        store.selectedID = store.items[1].id
        let deletedID = store.selectedID
        store.deleteSelected()
        let reloaded = CursorStore(directory: root)
        XCTAssertNil(reloaded.error)
        XCTAssertEqual(reloaded.items.count, 19)
        XCTAssertFalse(reloaded.items.contains { $0.id == deletedID })
        let edited = try XCTUnwrap(reloaded.items.first { $0.id == editedID })
        XCTAssertEqual(edited.name, "My swimmer")
        XCTAssertEqual(edited.size, 51)
        XCTAssertTrue(edited.isFavorite)
    }

    @MainActor
    func testUpgradeAdoptsUploadedOriginalsWithoutDuplicates() throws {
        let root = try directory()
        let collection = try BundledCollection.load()
        var existing = collection.map { $0.entry.item }
        for i in existing.indices {
            existing[i].name = collection[i].entry.originalName
            try collection[i].png.write(to: root.appendingPathComponent(existing[i].fileName))
        }
        existing[0].size = 55; existing[0].hotspotX = 0.3; existing[0].isFavorite = true
        try JSONEncoder().encode(existing).write(to: root.appendingPathComponent("library.json"))
        let store = CursorStore(directory: root)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.items.count, 20)
        XCTAssertEqual(store.items.map(\.name), collection.map { $0.entry.name })
        XCTAssertEqual(store.items[0].size, 55)
        XCTAssertEqual(store.items[0].hotspotX, 0.3)
        XCTAssertTrue(store.items[0].isFavorite)
        XCTAssertEqual(CursorStore(directory: root).items, store.items)
    }

    @MainActor
    func testUpgradeKeepsUnrelatedUserCursors() throws {
        let root = try directory()
        let id = UUID()
        let item = CursorItem(id: id, name: "My old cursor", fileName: "\(id).png", size: 46)
        try OriginalArtwork.png(OriginalArtwork.image(0)).write(to: root.appendingPathComponent(item.fileName))
        try JSONEncoder().encode([item]).write(to: root.appendingPathComponent("library.json"))
        let store = CursorStore(directory: root)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.items.count, 21)
        XCTAssertEqual(store.items.first, item)
    }

    @MainActor
    func testSystemDefaultRestoresPointerAndPackAndClearsCustomPreview() throws {
        var restores = 0
        let store = CursorStore(directory: try directory(), restoreSystemCursors: { restores += 1; return 0 })
        let originalItems = store.items
        let originalPacks = store.packs
        store.activeID = store.selectedID; store.appliedSnapshot = store.selected; store.needsRestore = true
        store.restore()
        XCTAssertEqual(restores, 1)
        XCTAssertFalse(store.hasActiveCursors)
        XCTAssertNil(store.selected)
        store.packMode = true; store.activePackID = store.selectedPackID
        store.appliedPackSnapshot = store.selectedPack; store.needsRestore = true
        store.restore()
        XCTAssertEqual(restores, 2)
        XCTAssertFalse(store.hasActiveCursors)
        XCTAssertFalse(store.packMode)
        XCTAssertNil(store.selectedID)
        XCTAssertEqual(store.items, originalItems)
        XCTAssertEqual(store.packs, originalPacks)
        store.restore()
        XCTAssertEqual(restores, 2, "No registry operation is needed when already restored")
    }

    @MainActor
    func testFailedRestoreKeepsRecoveryAndSelection() throws {
        let store = CursorStore(directory: try directory(), restoreSystemCursors: { -1 })
        let selected = store.selectedID
        store.activeID = selected; store.needsRestore = true
        store.restore()
        XCTAssertTrue(store.needsRestore)
        XCTAssertEqual(store.activeID, selected)
        XCTAssertEqual(store.selectedID, selected)
        XCTAssertNotNil(store.error)
    }
}
