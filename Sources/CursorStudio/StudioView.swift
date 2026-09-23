import SwiftUI
import AppKit

enum StudioStyle {
    static let accent = Color(red: 0.36, green: 0.47, blue: 0.29)
    static let yellow = Color(red: 0.97, green: 0.84, blue: 0.46)
    static let ink = Color(red: 0.20, green: 0.27, blue: 0.18)
    static let muted = Color(red: 0.43, green: 0.48, blue: 0.39)
    static let background = Color(red: 0.985, green: 0.98, blue: 0.94)
    static let line = Color.black.opacity(0.065)
}

struct StudioView: View {
    @EnvironmentObject private var store: CursorStore
    @State private var dropping = false
    @State private var showHelp = false
    @State private var showDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 20)
            Divider().overlay(StudioStyle.line)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 4) {
                        libraryTab("Cursors", packs: false)
                        libraryTab("Packs", packs: true)
                    }.padding(4).background(StudioStyle.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    if store.packMode { packLibrary } else { library }
                }
                .padding(20).frame(width: 260)
                .frame(maxHeight: .infinity)
                .background(Color.white.opacity(0.45))
                Divider().overlay(StudioStyle.line)
                Group {
                    if store.packMode {
                        PackEditor()
                    } else if let item = store.selected, let image = store.image(for: item) {
                        ScrollView {
                            CursorEditor(item: item, image: image).id(item.id).padding(2)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                                .font(.system(size: 38)).foregroundStyle(StudioStyle.accent)
                            Text(store.selected == nil ? "Add your first cursor" : "This image is missing")
                                .font(.title2.weight(.semibold))
                            Text(store.selected == nil ? "Drop an image here to get started." : "Import the image again to restore it.")
                                .foregroundStyle(StudioStyle.muted)
                            Button("Choose an image", action: store.chooseFiles).buttonStyle(PrimaryButtonStyle())
                            if store.selected != nil { Button("Remove missing cursor") { showDelete = true } }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxHeight: .infinity)
            if let notice = store.notice {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(StudioStyle.accent)
                    Text(notice).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button { store.notice = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss message").help("Dismiss message")
                }.foregroundStyle(StudioStyle.muted).padding(.horizontal, 24).padding(.vertical, 10)
                    .background(StudioStyle.accent.opacity(0.055))
            }
            footer
        }
        .frame(minWidth: 980, minHeight: 720)
        .background(StudioStyle.background)
        .foregroundStyle(StudioStyle.ink)
        .tint(StudioStyle.accent)
        .preferredColorScheme(.light)
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 16).fill(StudioStyle.accent.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(StudioStyle.accent, style: StrokeStyle(lineWidth: 3, dash: [8])))
                    .overlay(Label("Drop your images to import", systemImage: "arrow.down.doc").font(.title2.weight(.semibold)).padding(10))
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            store.importFiles(urls); return true
        } isTargeted: { dropping = $0 }
        .alert("Something needs your attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .sheet(isPresented: $showDelete) {
            ThemedConfirmation(
                title: "Remove missing cursor?", itemName: store.selected?.name,
                message: "This removes the missing cursor from your library. Your original image file stays untouched.",
                confirmTitle: "Remove cursor",
                cancel: { showDelete = false },
                confirm: { showDelete = false; store.deleteSelected() }
            )
        }
        .sheet(isPresented: $showHelp) { help }
    }

    private func libraryTab(_ title: String, packs: Bool) -> some View {
        Button { store.packMode = packs } label: {
            Text(title).font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                .foregroundStyle(store.packMode == packs ? StudioStyle.ink : StudioStyle.muted)
                .background(store.packMode == packs ? StudioStyle.yellow : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityAddTraits(store.packMode == packs ? .isSelected : [])
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: SoftBloomArtwork.pointerPreview).resizable().scaledToFit()
                .frame(width: 40, height: 40)
            Text("Cute Cursor").font(.system(size: 23, weight: .semibold, design: .rounded))
            Spacer()
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle").font(.system(size: 18)) }
                .buttonStyle(.plain).foregroundStyle(StudioStyle.muted)
                .accessibilityLabel("Help").help("Importing, editing, and applying cursors")
            Button(action: store.chooseFiles) { Label("Import", systemImage: "square.and.arrow.down") }
                .buttonStyle(SecondaryButtonStyle()).help("Import images or a cursor pack (⌘O)")
            if store.packMode {
                Button(action: store.createPack) { Label("New pack", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }.font(.system(size: 12, weight: .medium))
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.favoritesOnly ? "Favorites" : "Your cursors").font(.system(size: 14, weight: .semibold))
                Text("\(store.visibleItems.count)").font(.system(size: 11)).foregroundStyle(StudioStyle.muted)
                Spacer()
                Button { store.favoritesOnly.toggle() } label: {
                    Image(systemName: store.favoritesOnly ? "heart.fill" : "heart")
                        .foregroundStyle(store.favoritesOnly ? StudioStyle.accent : StudioStyle.muted)
                }.buttonStyle(.plain)
                    .accessibilityLabel(store.favoritesOnly ? "Show all cursors" : "Show favorites")
                    .help(store.favoritesOnly ? "Show all cursors" : "Show favorites")
            }
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(StudioStyle.muted)
                TextField("Find a cursor", text: $store.search).textFieldStyle(.plain)
            }.font(.system(size: 12)).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(StudioStyle.line))
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.visibleItems) { item in
                        Button { store.selectedID = item.id } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let image = store.image(for: item) { Image(nsImage: image).resizable().interpolation(.high).scaledToFit() }
                                    else { Image(systemName: "photo.badge.exclamationmark") }
                                }.frame(width: 47, height: 47).padding(5).background(StudioStyle.background, in: RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Text(store.activeID == item.id ? "Applied" : item.sourceNote).font(.system(size: 9)).foregroundStyle(store.activeID == item.id ? StudioStyle.accent : StudioStyle.muted).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if item.isFavorite { Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(StudioStyle.accent) }
                            }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(store.selectedID == item.id ? StudioStyle.accent.opacity(0.7) : StudioStyle.line, lineWidth: store.selectedID == item.id ? 1.5 : 1))
                        }.buttonStyle(.plain)
                    }
                    if store.visibleItems.isEmpty {
                        Text(store.search.isEmpty ? "Nothing here yet. Add a cursor or favorite one from your collection." : "No cursors match “\(store.search)”.")
                            .font(.system(size: 12)).foregroundStyle(StudioStyle.muted).padding(.vertical, 22).multilineTextAlignment(.center)
                    }
                }.padding(2)
            }.scrollIndicators(.hidden)
        }
    }

    private var packLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your packs").font(.system(size: 14, weight: .semibold))
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.packs) { pack in
                        Button { store.selectedPackID = pack.id } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    ForEach(Array(CursorRole.allCases.prefix(4))) { role in
                                        if let item = pack[role], let image = store.image(for: item) {
                                            Image(nsImage: image).resizable().scaledToFit().frame(width: 25, height: 30)
                                        } else { Image(systemName: role.symbol).frame(width: 25, height: 30).foregroundStyle(StudioStyle.muted) }
                                    }
                                }
                                Text(pack.name).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                                Text(store.activePackID == pack.id ? "Applied" : "\(pack.cursors.count) cursor slots").font(.system(size: 10)).foregroundStyle(StudioStyle.muted)
                            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(store.selectedPackID == pack.id ? StudioStyle.accent : StudioStyle.line))
                        }.buttonStyle(.plain)
                    }
                }.padding(2)
            }
        }
    }

    private var selectionIsApplied: Bool {
        if store.packMode {
            return store.selectedPackID != nil && store.activePackID == store.selectedPackID && !store.hasUnappliedPackChanges
        }
        return store.selectedID != nil && store.activeID == store.selectedID && !store.hasUnappliedChanges
    }

    private var canApply: Bool {
        guard store.systemAvailable else { return false }
        if store.packMode { return store.selectedPack?.cursors.isEmpty == false }
        guard let item = store.selected else { return false }
        return store.image(for: item) != nil
    }

    private var footer: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Circle().fill(store.hasActiveCursors ? StudioStyle.accent : Color.gray.opacity(0.45))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.hasActiveCursors ? "Custom cursors active" : "Default cursors active")
                        .font(.system(size: 12, weight: .medium))
                    Text(!store.systemAvailable ? "System apply is unavailable on this Mac" :
                         (store.packMode ? store.hasUnappliedPackChanges : store.hasUnappliedChanges) ?
                         "You have changes to apply" : "Applies across your Mac")
                        .font(.system(size: 11)).foregroundStyle(StudioStyle.muted)
                }
            }
            Spacer(minLength: 12)
            Button(action: store.restore) { Label("Restore default", systemImage: "arrow.counterclockwise") }
                .buttonStyle(SecondaryButtonStyle()).disabled(!store.hasActiveCursors)
                .help("Restore your original Mac cursors (⌘R)")
            Button(action: store.apply) {
                Label(selectionIsApplied ? "Applied" : store.packMode ? "Apply pack" : "Apply cursor",
                      systemImage: selectionIsApplied ? "checkmark" : "cursorarrow.rays")
                    .frame(minWidth: 100)
            }.buttonStyle(PrimaryButtonStyle()).disabled(!canApply || selectionIsApplied)
                .help("Apply the selected cursor or pack (⌘Return). Some apps use their own cursors.")
        }.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 24).padding(.vertical, 16)
            .background(.white.opacity(0.75))
            .overlay(alignment: .top) { Rectangle().fill(StudioStyle.line).frame(height: 1) }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Using Cute Cursor").font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("1. Add an image\nDrop a file anywhere or choose Import. PNG, JPEG, WebP, HEIC, TIFF, BMP, ICO, GIF, and decodable static CUR files are supported. GIFs use the first frame; ANI and SVG aren’t supported.")
            Text("2. Make it feel right\nChoose a size, then click the preview to set the exact point that clicks. Move your mouse around the test area to try it.")
            Text("3. Make a matching pack\nOpen Packs to customize pointer, link, text, hands, resize, crosshair, and not-allowed cursors. Empty slots keep the originals. Export a .cutecursor file to share the whole pack. Apply uses an experimental macOS feature; some apps draw their own cursors.")
            Text("Restore default is always available here and in the menu bar. Your original cursors are restored when you quit. Closing the window keeps the app running in the menu bar. Your library is saved locally; nothing is uploaded.")
            Button("Got it") { showHelp = false }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity, alignment: .trailing)
        }.font(.system(size: 13)).lineSpacing(4).padding(32).frame(width: 540)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 18).padding(.vertical, 12)
            .foregroundStyle(StudioStyle.ink.opacity(enabled ? 1 : 0.45)).background(StudioStyle.yellow.opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 14).padding(.vertical, 12)
            .foregroundStyle(StudioStyle.ink.opacity(enabled ? 1 : 0.35))
            .background(configuration.isPressed ? StudioStyle.yellow.opacity(0.35) : StudioStyle.accent.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(StudioStyle.line))
    }
}
