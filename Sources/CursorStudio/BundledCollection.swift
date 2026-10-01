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
    func migrateBundledNames() throws {
        let receipt = directory.appendingPathComponent("bundled-collection.json")
        var installed = try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: receipt))
        let version = "cute-collection-names-v2"
        guard !installed.contains(version) else { return }
        // Only rename known stock entries that still have their previous name.
        // Never recreate deleted entries or overwrite a user's custom name.
        let replacements: [UUID: (old: String, new: String)] = [
            UUID(uuidString: "E9C8EC9B-CAB9-4B4F-8FCE-D6B9847922DD")!: ("Little Swimmer", "Ancestor"),
            UUID(uuidString: "B90F2269-998D-4A1B-A0C8-9D9BA2D6230A")!: ("Cigarette", "No Smoking")
        ]
        let previous = items
        for index in items.indices {
            if let replacement = replacements[items[index].id], items[index].name == replacement.old {
                items[index].name = replacement.new
            }
        }
        do { if items != previous { try persist() } }
        catch { items = previous; throw error }
        installed.insert(version)
        try JSONEncoder().encode(installed).write(to: receipt, options: .atomic)
    }

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
