import AppKit
import CursorSystem
import UniformTypeIdentifiers

extension CursorStore {
    func loadPacks() throws {
        let url = directory.appendingPathComponent("packs.json")
        if FileManager.default.fileExists(atPath: url.path) {
            packs = try JSONDecoder().decode([CursorPack].self, from: Data(contentsOf: url))
            guard Set(packs.map(\.id)).count == packs.count else { throw CocoaError(.fileReadCorruptFile) }
            for pack in packs {
                guard !pack.name.isEmpty, pack.name.count <= 80,
                      pack.cursors.allSatisfy({ CursorRole(rawValue: $0.key) != nil && $0.value.isValid }) else { throw CocoaError(.fileReadCorruptFile) }
            }
        }
        // A separate receipt preserves user renames, edits, and intentional deletion.
        let receipt = directory.appendingPathComponent("bundled-packs.json")
        var installed = Set<String>()
        if FileManager.default.fileExists(atPath: receipt.path) {
            installed = try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: receipt))
        }
        if !installed.contains("soft-bloom-v1") {
            if !packs.contains(where: { $0.id == SoftBloomArtwork.packID }) {
                var pack = CursorPack(id: SoftBloomArtwork.packID, name: "Soft Bloom")
                var created: [URL] = []
                do {
                    for role in CursorRole.allCases {
                        let id = UUID(); let file = "\(id).png"
                        let url = directory.appendingPathComponent(file)
                        try OriginalArtwork.png(SoftBloomArtwork.image(for: role)).write(to: url, options: .atomic)
                        created.append(url)
                        let point = SoftBloomArtwork.hotspot(for: role)
                        pack[role] = CursorItem(id: id, name: role.title, fileName: file, size: 40,
                            hotspotX: point.x, hotspotY: point.y, sourceNote: "Soft Bloom original")
                    }
                    packs.insert(pack, at: 0)
                    do { try persistPacks() } catch { packs.removeFirst(); throw error }
                } catch {
                    for url in created { try? FileManager.default.removeItem(at: url) }
                    throw error
                }
            }
            installed.insert("soft-bloom-v1")
            try JSONEncoder().encode(installed).write(to: receipt, options: .atomic)
        }
    }

    func persistPacks() throws {
        guard canWrite else { throw CocoaError(.fileWriteNoPermission) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(packs).write(to: directory.appendingPathComponent("packs.json"), options: .atomic)
    }

    func createPack() {
        let previous = packs
        let pack = CursorPack(name: "My cursor pack")
        packs.append(pack)
        do { try persistPacks(); selectedPackID = pack.id; selectedRole = .pointer; packMode = true }
        catch { packs = previous; self.error = "Couldn’t create the pack. \(error.localizedDescription)" }
    }

    func renamePack(_ name: String) {
        guard let index = packs.firstIndex(where: { $0.id == selectedPackID }) else { return }
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        let previous = packs[index].name; packs[index].name = name
        do { try persistPacks() } catch { packs[index].name = previous; self.error = error.localizedDescription }
    }

    func assign(_ item: CursorItem?, to role: CursorRole) {
        guard let index = packs.firstIndex(where: { $0.id == selectedPackID }) else { return }
        let previous = packs
        var copy = item; copy?.id = UUID(); copy?.isFavorite = false
        packs[index][role] = copy
        do { try persistPacks() } catch { packs = previous; self.error = error.localizedDescription }
    }

    func importSlot(_ role: CursorRole) {
        guard let index = packs.firstIndex(where: { $0.id == selectedPackID }) else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageImporter.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.message = "Choose the image for \(role.title). Transparent PNG works best."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var destination: URL?
        let previous = packs
        do {
            let result = try ImageImporter.read(url)
            let id = UUID(); let file = "\(id).png"
            destination = directory.appendingPathComponent(file)
            try result.png.write(to: destination!, options: .atomic)
            packs[index][role] = CursorItem(id: id, name: role.title, fileName: file,
                hotspotX: Double(result.hotspot?.x ?? 0.5), hotspotY: Double(result.hotspot?.y ?? 0.5), sourceNote: "Pack image")
            try persistPacks()
            images[id] = result.image
            if result.frameCount > 1 { notice = "This image uses its first frame. Animation isn’t supported yet." }
        } catch {
            packs = previous
            if let destination { try? FileManager.default.removeItem(at: destination) }
            self.error = "Couldn’t add this image. \(error.localizedDescription)"
        }
    }

    func deletePack() {
        guard let pack = selectedPack else { return }
        if activePackID == pack.id { restore(); if hasActiveCursors { return } }
        let previous = packs; packs.removeAll { $0.id == pack.id }
        do { try persistPacks(); selectedPackID = packs.first?.id }
        catch { packs = previous; self.error = error.localizedDescription }
        // Images are kept: another pack/library entry may reference them.
    }

    func portablePack(_ pack: CursorPack) throws -> Data {
        let slots = try CursorRole.allCases.compactMap { role -> PortablePack.Slot? in
            guard let item = pack[role] else { return nil }
            guard let image = image(for: item) else { throw PackError.invalid("The image for \(role.title) is missing. Replace it before exporting.") }
            return PortablePack.Slot(role: role, name: item.name, size: item.size,
                hotspotX: item.hotspotX, hotspotY: item.hotspotY, png: OriginalArtwork.png(image))
        }
        let data = try JSONEncoder().encode(PortablePack(name: pack.name, cursors: slots))
        _ = try PortablePack.decode(data)
        return data
    }

    func exportPack() {
        guard let pack = selectedPack else { return }
        do {
            let data = try portablePack(pack)
            let panel = NSSavePanel(); panel.allowedContentTypes = [PortablePack.contentType]
            panel.nameFieldStringValue = "\(pack.name).\(PortablePack.fileExtension)"
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: .atomic)
                notice = "Pack exported with its images, sizes, and click points."
            }
        } catch { self.error = "Couldn’t export the pack. \(error.localizedDescription)" }
    }

    func importPack(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 16 * 1024 * 1024 else { throw PackError.invalid("The pack exceeds 16 MB.") }
        let portable = try PortablePack.decode(Data(contentsOf: url))
        var pack = CursorPack(name: portable.name)
        var written: [URL] = []
        let previous = packs
        do {
            for slot in portable.cursors {
                let id = UUID(); let file = "\(id).png"; let destination = directory.appendingPathComponent(file)
                try slot.png.write(to: destination, options: .atomic); written.append(destination)
                pack[slot.role] = CursorItem(id: id, name: slot.name, fileName: file, size: slot.size,
                    hotspotX: slot.hotspotX, hotspotY: slot.hotspotY, sourceNote: "Imported pack")
            }
            packs.append(pack); try persistPacks()
            selectedPackID = pack.id; selectedRole = .pointer; packMode = true
        } catch {
            packs = previous; for url in written { try? FileManager.default.removeItem(at: url) }; throw error
        }
    }

    func syncRecoveryState() {
        needsRestore = CSHasAppliedCursors()
        if !needsRestore { activeID = nil; activePackID = nil; appliedSnapshot = nil; appliedPackSnapshot = nil }
    }

    func applyPack() {
        guard let pack = selectedPack, !pack.cursors.isEmpty else { error = "Add at least one cursor to the pack first."; return }
        CursorRole.prepareSystemCursors()
        var definitions: [CSCursorDefinition] = []
        // Hold the CGImages alive for the complete C operation.
        var retainedImages: [CGImage] = []
        for role in CursorRole.allCases {
            guard let item = pack[role] else { continue }
            guard let image = image(for: item), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                error = "The image for \(role.title) is missing. Replace it before applying."; return
            }
            let size = item.dimensions(for: image), point = item.hotspot(for: image)
            retainedImages.append(cg)
            definitions.append(CSCursorDefinition(role: role.systemIndex, image: .passUnretained(cg), width: size.width, height: size.height, x: point.x, y: point.y))
        }
        let result = withExtendedLifetime(retainedImages) {
            definitions.withUnsafeBufferPointer { CSApplyCursors($0.baseAddress, $0.count) }
        }
        if result == 0 {
            activeID = nil; appliedSnapshot = nil; activePackID = pack.id; appliedPackSnapshot = pack; needsRestore = true
            notice = "\(pack.name) applied. Apps with their own cursors may look different."
        } else {
            syncRecoveryState()
            if result == -4 { activeID = nil; activePackID = nil; appliedSnapshot = nil; appliedPackSnapshot = nil }
            if (-110 ... -100).contains(result) {
                let role = CursorRole.allCases[Int(-result - 100)]
                error = "\(role.title) isn’t available for replacement on this Mac. Leave that slot empty and try again. Your previous cursors were kept."
            } else {
                error = "The pack couldn’t be applied (code \(result)). \(needsRestore ? "Use Restore default if any cursors look wrong." : "Your original cursors have been restored.")"
            }
        }
    }
}
