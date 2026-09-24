import AppKit

enum BundledCollection {
    struct Entry: Decodable {
        let id: UUID
        let name: String
        let originalName: String
        let resource: String
        let hotspotX: Double
        let hotspotY: Double

        var item: CursorItem {
            CursorItem(id: id, name: name, fileName: "\(id.uuidString).png",
                       hotspotX: hotspotX, hotspotY: hotspotY, sourceNote: "Cute Cursor original")
        }
    }

    static func load() throws -> [(entry: Entry, png: Data)] {
        let bundle = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
        guard let directory = bundle.url(forResource: "Collection", withExtension: nil) else {
            throw PackError.invalid("The bundled cursor collection is missing. Reinstall Cute Cursor to restore it.")
        }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: directory.appendingPathComponent("catalog.json")))
        guard entries.count == 20, Set(entries.map(\.id)).count == entries.count,
              Set(entries.map(\.name)).count == entries.count else {
            throw PackError.invalid("The bundled cursor collection is invalid.")
        }
        return try entries.map { entry in
            guard entry.item.isValid, entry.resource == URL(fileURLWithPath: entry.resource).lastPathComponent,
                  entry.resource.hasSuffix(".png") else { throw PackError.invalid("A bundled cursor is invalid.") }
            return (entry, try ImageImporter.read(directory.appendingPathComponent(entry.resource)).png)
        }
    }
}

extension CursorStore {
    func loadBundledCollection() throws {
        let receipt = directory.appendingPathComponent("bundled-collection.json")
        let version = "cute-collection-v1"
        var installed: Set<String> = []
        if FileManager.default.fileExists(atPath: receipt.path) {
            installed = try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: receipt))
        }
        guard !installed.contains(version) else { return }
        let collection = try BundledCollection.load() // Validate all images before writing.
        let previous = items
        var created: [URL] = []
        do {
            for (entry, png) in collection {
                if let index = items.firstIndex(where: { $0.id == entry.id }) {
                    // Adopt the maintainer's uploaded originals without duplicates or
                    // losing custom sizes, click points, favorites, or later renames.
                    if items[index].name == entry.originalName { items[index].name = entry.name }
                    items[index].sourceNote = entry.item.sourceNote
                    continue
                }
                var item = entry.item
                var destination = directory.appendingPathComponent(item.fileName)
                if FileManager.default.fileExists(atPath: destination.path) {
                    item.fileName = "\(UUID().uuidString).png"
                    destination = directory.appendingPathComponent(item.fileName)
                }
                try png.write(to: destination, options: .atomic)
                created.append(destination)
                items.append(item)
            }
            try persist()
        } catch {
            items = previous
            for file in created { try? FileManager.default.removeItem(at: file) }
            throw error
        }
        // If this final write fails, retained IDs make the next attempt idempotent.
        installed.insert(version)
        try JSONEncoder().encode(installed).write(to: receipt, options: .atomic)
    }
}
