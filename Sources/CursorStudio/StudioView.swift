import SwiftUI
import AppKit

enum StudioStyle {
    static let accent = Color(red: 0.43, green: 0.32, blue: 0.78)
    static let ink = Color(red: 0.17, green: 0.18, blue: 0.22)
    static let muted = Color(red: 0.49, green: 0.49, blue: 0.54)
    static let background = Color(red: 0.975, green: 0.97, blue: 0.955)
    static let line = Color.black.opacity(0.065)
}

struct StudioView: View {
    @EnvironmentObject private var store: CursorStore
    @State private var dropping = false
    @State private var showHelp = false
    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(StudioStyle.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 24) {
                header
                HStack(alignment: .top, spacing: 24) {
                    if store.packMode {
                        packLibrary.frame(width: 210)
                        PackEditor()
                    } else {
                    library.frame(width: 210)
                    if let item = store.selected, let image = store.image(for: item) {
                        CursorEditor(item: item, image: image).id(item.id)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "cursorarrow.and.square.on.square.dashed").font(.system(size: 38)).foregroundStyle(StudioStyle.accent)
                            Text(store.selected == nil ? "Your next favorite pointer" : "This image is missing").font(.title2.weight(.semibold))
                            Text(store.selected == nil ? "Drop an image here to make it yours." : "Import the image again to restore it.").foregroundStyle(StudioStyle.muted)
                            Button("Choose an image", action: store.chooseFiles).buttonStyle(PrimaryButtonStyle())
                            if store.selected != nil { Button("Remove missing cursor") { showDelete = true } }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    }
                }.frame(maxHeight: .infinity)
                footer
            }.padding(.horizontal, 30).padding(.top, 38).padding(.bottom, 20)
        }
        .frame(minWidth: 1050, minHeight: 780)
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
        .confirmationDialog("Remove this cursor from your library?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Remove Cursor", role: .destructive, action: store.deleteSelected)
        } message: { Text("Your original image file will stay untouched.") }
        .sheet(isPresented: $showHelp) { help }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 10) {
                Image(systemName: "cursorarrow").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(StudioStyle.accent, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cute").font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("CURSOR").font(.system(size: 9, weight: .semibold)).tracking(3).foregroundStyle(StudioStyle.muted)
                }
            }.padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 7) {
                Text("YOUR SPACE").font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(StudioStyle.muted).padding(.leading, 12).padding(.bottom, 8)
                navigation("Cursor packs", icon: "square.stack.3d.up", selected: store.packMode, count: store.packs.count) { store.packMode = true }
                navigation("All cursors", icon: "square.grid.2x2", selected: !store.packMode && !store.favoritesOnly, count: store.items.count) { store.packMode = false; store.favoritesOnly = false }
                navigation("Favorites", icon: "heart", selected: !store.packMode && store.favoritesOnly, count: store.items.filter(\.isFavorite).count) { store.packMode = false; store.favoritesOnly = true }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(StudioStyle.accent)
                Text("Small pointer.\nBig personality.").font(.system(size: 16, weight: .medium, design: .rounded)).lineSpacing(3)
                Text("Made for the little things\nyou do all day.").font(.system(size: 11)).foregroundStyle(StudioStyle.muted).lineSpacing(3)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
            Button { showHelp = true } label: { Label("A little help", systemImage: "questionmark.circle").font(.system(size: 12)) }.buttonStyle(.plain).foregroundStyle(StudioStyle.muted).padding(.leading, 10)
            Text("ON YOUR MAC. JUST FOR YOU.").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(StudioStyle.muted.opacity(0.8)).padding(.leading, 10)
        }.padding(.horizontal, 18).padding(.top, 57).padding(.bottom, 24)
            .frame(width: 192).background(Color(red: 0.945, green: 0.936, blue: 0.916))
    }

    private func navigation(_ title: String, icon: String, selected: Bool, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon).frame(width: 16); Text(title); Spacer(); Text("\(count)").font(.system(size: 10)).opacity(0.7) }
                .font(.system(size: 12, weight: selected ? .semibold : .regular)).padding(12)
                .foregroundStyle(selected ? StudioStyle.accent : StudioStyle.muted)
                .background(selected ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("A little more you.").font(.system(size: 30, weight: .semibold, design: .rounded)).tracking(-0.7)
                Text(store.packMode ? "A matching set for every little moment." : "Give your everyday pointer a personality.").font(.system(size: 13)).foregroundStyle(StudioStyle.muted)
            }
            Spacer()
            Button(action: store.packMode ? store.createPack : store.chooseFiles) { Label(store.packMode ? "New pack" : "Add cursor", systemImage: "plus").font(.system(size: 13, weight: .semibold)) }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut("o")
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(store.favoritesOnly ? "Favorites" : "Your collection").font(.system(size: 14, weight: .semibold)); Spacer(); Text("\(store.visibleItems.count)").foregroundStyle(StudioStyle.muted).font(.system(size: 11)) }
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
                        }.buttonStyle(.plain).contextMenu {
                            Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") { store.selectedID = item.id; store.update { $0.isFavorite.toggle() } }
                            Button("Export PNG…") { store.selectedID = item.id; store.exportSelected() }
                            Button("Remove…", role: .destructive) { store.selectedID = item.id; showDelete = true }
                        }
                    }
                    if store.visibleItems.isEmpty {
                        Text(store.search.isEmpty ? "Nothing here yet. Add a cursor or favorite one from your collection." : "No cursors match “\(store.search)”.")
                            .font(.system(size: 12)).foregroundStyle(StudioStyle.muted).padding(.vertical, 22).multilineTextAlignment(.center)
                    }
                    Button(action: store.chooseFiles) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc").font(.system(size: 21, weight: .light))
                            Text("Drop something fun").font(.system(size: 12, weight: .medium))
                            Text("PNG, JPG, GIF, WebP + more").font(.system(size: 9)).foregroundStyle(StudioStyle.muted)
                        }.foregroundStyle(StudioStyle.accent).frame(maxWidth: .infinity).padding(.vertical, 25)
                            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(StudioStyle.accent.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                    }.buttonStyle(.plain).padding(.top, 4)
                }.padding(2)
            }.scrollIndicators(.hidden)
            Text("Transparent PNGs work best.\nGIFs use the first frame.").font(.system(size: 10)).foregroundStyle(StudioStyle.muted).lineSpacing(3)
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
            Button("Import pack…", action: store.chooseFiles)
            Text("Share a .cutecursor file.\nImages and click points travel together.").font(.system(size: 10)).foregroundStyle(StudioStyle.muted).lineSpacing(3)
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(!store.hasActiveCursors ? Color.gray.opacity(0.45) : Color.green).frame(width: 6, height: 6)
            Text(store.notice ?? (!store.hasActiveCursors ? "Original Mac cursors are active" : "Custom cursors are active"))
                .font(.system(size: 10)).foregroundStyle(StudioStyle.muted).lineLimit(2)
            Spacer()
            Button("Restore default", action: store.restore).font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(StudioStyle.accent).disabled(!store.hasActiveCursors)
        }.padding(.top, 12).overlay(alignment: .top) { Rectangle().fill(StudioStyle.line).frame(height: 1) }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Make yourself at pointer.").font(.system(size: 24, weight: .semibold, design: .rounded))
            Text("1. Add an image\nDrop a file anywhere or choose Add cursor. PNG, JPEG, WebP, HEIC, TIFF, BMP, ICO, GIF, and decodable static CUR files are supported. GIFs use the first frame; ANI and SVG aren’t supported.")
            Text("2. Make it feel right\nChoose a size, then click the preview to set the exact point that clicks. Move your mouse around the test area to try it.")
            Text("3. Make a matching pack\nOpen Cursor packs to customize pointer, link, text, hands, resize, crosshair, and not-allowed cursors. Empty slots keep the originals. Export a .cutecursor file to share the whole pack. Apply uses an experimental macOS feature; some apps draw their own cursors.")
            Text("Restore default is always available here and in the menu bar. Your original cursors are restored when you quit. Closing the window keeps the app running in the menu bar. Your library is saved locally; nothing is uploaded.")
            Button("Got it") { showHelp = false }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity, alignment: .trailing)
        }.font(.system(size: 13)).lineSpacing(4).padding(32).frame(width: 540)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 18).padding(.vertical, 12)
            .foregroundStyle(.white).background(StudioStyle.accent.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}
