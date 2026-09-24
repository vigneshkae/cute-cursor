import AppKit
import SwiftUI
import CursorSystem
import UniformTypeIdentifiers

@MainActor
final class CursorStore: ObservableObject {
    @Published var items: [CursorItem] = []
    @Published var selectedID: UUID?
    @Published var packs: [CursorPack] = []
    @Published var selectedPackID: UUID?
    @Published var selectedRole: CursorRole = .pointer
    @Published var packMode = false
    @Published var activePackID: UUID?
    @Published var appliedPackSnapshot: CursorPack?
    @Published var needsRestore = false
    @Published var error: String?
    @Published var notice: String?
    @Published var activeID: UUID?
    @Published var appliedSnapshot: CursorItem?
    @Published var search = ""
    @Published var favoritesOnly = false
    private(set) var directory: URL
    var images: [UUID: NSImage] = [:]
    var canWrite = true
    private let restoreSystemCursors: () -> Int32

    init(directory: URL? = nil, restoreSystemCursors: @escaping () -> Int32 = { CSRestorePointer() }) {
        self.restoreSystemCursors = restoreSystemCursors
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CursorStudio", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let manifest = self.directory.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: manifest.path) {
                items = try JSONDecoder().decode([CursorItem].self, from: Data(contentsOf: manifest))
                guard Set(items.map(\.id)).count == items.count else { throw CocoaError(.fileReadCorruptFile) }
                for item in items {
                    guard item.isValid else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                }
            }
            try loadPacks()
            try loadBundledCollection()
            selectedID = items.first?.id
            selectedPackID = packs.first(where: { $0.id == SoftBloomArtwork.packID })?.id ?? packs.first?.id
        } catch {
            canWrite = false
            self.error = "Your library couldn’t be opened. Existing files have been kept safe. \(error.localizedDescription)"
        }
    }

    var selectedPack: CursorPack? { packs.first { $0.id == selectedPackID } }
    var selected: CursorItem? {
        packMode ? selectedPack?[selectedRole] : items.first { $0.id == selectedID }
    }
    var hasActiveCursors: Bool { activeID != nil || activePackID != nil || needsRestore }
    var hasUnappliedPackChanges: Bool { activePackID == selectedPackID && selectedPack != appliedPackSnapshot }
    var visibleItems: [CursorItem] {
        items.filter { (!favoritesOnly || $0.isFavorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }
    var systemAvailable: Bool { CSSystemAvailable() }
    var hasUnappliedChanges: Bool { activeID == selectedID && selected != appliedSnapshot }

    func image(for item: CursorItem) -> NSImage? {
        if let cached = images[item.id] { return cached }
        let image = NSImage(contentsOf: directory.appendingPathComponent(item.fileName))
        images[item.id] = image
        return image
    }

    func persist() throws {
        guard canWrite else { throw CocoaError(.fileWriteNoPermission) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: directory.appendingPathComponent("library.json"), options: .atomic)
    }

    func update(_ mutate: (inout CursorItem) -> Void) {
        if packMode {
            guard let packIndex = packs.firstIndex(where: { $0.id == selectedPackID }), var item = packs[packIndex][selectedRole] else { return }
            let previous = packs
            mutate(&item)
            guard item.isValid else { error = "The cursor settings aren’t valid."; return }
            packs[packIndex][selectedRole] = item
            do { try persistPacks() } catch { packs = previous; self.error = error.localizedDescription }
            return
        }
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        let before = items[index]
        mutate(&items[index])
        guard items[index].isValid else { items[index] = before; error = "The cursor settings aren’t valid."; return }
        do { try persist() } catch { items[index] = before; self.error = "Couldn’t save your change. \(error.localizedDescription)" }
    }

    func importFiles(_ urls: [URL]) {
        var failures: [String] = []
        var imported = 0
        var flattened = false
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                if url.pathExtension.lowercased() == PortablePack.fileExtension {
                    try importPack(url); imported += 1; continue
                }
                let result = try ImageImporter.read(url)
                let id = UUID(); let file = "\(id).png"
                let item = CursorItem(id: id, name: String(url.deletingPathExtension().lastPathComponent.prefix(80)), fileName: file,
                                      hotspotX: Double(result.hotspot?.x ?? 0.1), hotspotY: Double(result.hotspot?.y ?? 0.1),
                                      sourceNote: result.frameCount > 1 ? "First frame · \(url.pathExtension.uppercased())" : "Imported · \(url.pathExtension.uppercased())")
                let destination = directory.appendingPathComponent(file)
                try result.png.write(to: destination, options: .atomic)
                items.append(item)
                do { try persist() } catch { items.removeAll { $0.id == id }; try? FileManager.default.removeItem(at: destination); throw error }
                images[id] = result.image; selectedID = id
                imported += 1; flattened = flattened || result.frameCount > 1
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        if imported > 0 {
            search = ""; favoritesOnly = false
            notice = flattened ? "Imported. Animated or multi-image files use the first frame." : "\(imported == 1 ? "Your cursor is" : "Your cursors are") ready to customize."
        }
        if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageImporter.extensions.compactMap { UTType(filenameExtension: $0) } + [PortablePack.contentType]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose an image. Transparent PNGs work best. GIFs use the first frame."
        if panel.runModal() == .OK { packMode = false; importFiles(panel.urls) }
    }

    func exportSelected() {
        guard let selected, let image = image(for: selected) else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(selected.name).png"
        if panel.runModal() == .OK, let url = panel.url {
            do { try OriginalArtwork.png(image).write(to: url, options: .atomic); notice = "PNG exported. Click-point settings stay in your library." }
            catch { self.error = "Couldn’t export this cursor. \(error.localizedDescription)" }
        }
    }

    func deleteSelected() {
        guard let item = selected else { return }
        if packMode { assign(nil, to: selectedRole); return }
        if activeID == item.id { restore(); if activeID != nil { return } }
        let previous = items
        items.removeAll { $0.id == item.id }
        do {
            try persist(); images[item.id] = nil; selectedID = items.first?.id
            let inPack = packs.contains { $0.cursors.values.contains { $0.fileName == item.fileName } }
            let file = directory.appendingPathComponent(item.fileName)
            if !inPack && FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        } catch { items = previous; try? persist(); self.error = "Couldn’t remove this cursor. \(error.localizedDescription)" }
    }

    func apply() {
        if packMode { applyPack(); return }
        guard let item = selected, let image = image(for: item), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let dimensions = item.dimensions(for: image); let point = item.hotspot(for: image)
        let result = CSApplyPointer(cgImage, dimensions.width, dimensions.height, point.x, point.y)
        if result == 0 {
            activeID = item.id; appliedSnapshot = item; activePackID = nil; appliedPackSnapshot = nil; needsRestore = true
            notice = "Pointer applied. Some apps may use their own cursor."
        } else { syncRecoveryState(); if result == -4 { activeID = nil; activePackID = nil; appliedSnapshot = nil; appliedPackSnapshot = nil }; error = "macOS couldn’t apply this pointer (code \(result)). You can still use the test area. If you changed pointer colors in Accessibility settings, reset those colors and try again." }
    }

    func restore() {
        let result = hasActiveCursors ? restoreSystemCursors() : 0
        if result == 0 { activeID = nil; appliedSnapshot = nil; activePackID = nil; appliedPackSnapshot = nil; needsRestore = false; selectedID = nil; packMode = false; notice = "System default cursors restored." }
        else { needsRestore = true; error = "macOS couldn’t restore the pointer (code \(result)). Try again; signing out also clears this session’s custom pointer." }
    }
}
