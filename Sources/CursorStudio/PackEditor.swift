import SwiftUI

struct PackEditor: View {
    @EnvironmentObject var store: CursorStore
    @State private var showDelete = false
    @State private var showRename = false
    @State private var draftName = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let pack = store.selectedPack {
                HStack {
                    Text(pack.name).font(.system(size: 22, weight: .semibold, design: .rounded)).lineLimit(2)
                    Button { draftName = pack.name; showRename = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Rename pack").help("Rename this pack")
                    Spacer(minLength: 8)
                    Button(action: store.exportPack) { Label("Export", systemImage: "square.and.arrow.up") }
                        .buttonStyle(SecondaryButtonStyle()).disabled(pack.cursors.isEmpty)
                    ThemedMenu(accessibilityName: "Pack actions", items: [
                        ThemedMenuItem(title: "Rename pack…", symbol: "pencil") { draftName = pack.name; showRename = true },
                        ThemedMenuItem(title: "Remove pack…", symbol: "trash", destructive: true) { showDelete = true }
                    ])
                }
                Text("\(pack.cursors.count) of 11 slots · Empty slots use your original cursors.")
                    .font(.system(size: 11)).foregroundStyle(StudioStyle.muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                        ForEach(CursorRole.allCases) { role in
                            Button { store.selectedRole = role } label: {
                                VStack(spacing: 6) {
                                    Group {
                                        if let item = pack[role], let image = store.image(for: item) {
                                            Image(nsImage: image).resizable().scaledToFit()
                                        } else { Image(systemName: role.symbol).foregroundStyle(StudioStyle.muted) }
                                    }.frame(width: 25, height: 25)
                                    Text(role.title).font(.system(size: 9)).lineLimit(1)
                                }.frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(store.selectedRole == role ? StudioStyle.accent.opacity(0.12) : .white, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(store.selectedRole == role ? StudioStyle.accent : StudioStyle.line))
                            }.buttonStyle(.plain).accessibilityLabel("\(role.title), \(pack[role] == nil ? "original" : "custom")")
                        }
                }.padding(2)
                HStack {
                    Text(store.selectedRole.title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    ThemedMenu(title: "From library", symbol: "chevron.down", items: store.items.map { item in
                        ThemedMenuItem(title: item.name, image: store.image(for: item)) { store.assign(item, to: store.selectedRole) }
                    })
                    Button { store.importSlot(store.selectedRole) } label: { Label("Choose image", systemImage: "photo") }
                        .buttonStyle(SecondaryButtonStyle())
                }
                ScrollView {
                    if let item = store.selected, let image = store.image(for: item) {
                        CursorEditor(item: item, image: image, inPack: true).id(item.id).padding(2)
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: store.selectedRole.symbol).font(.system(size: 40)).foregroundStyle(StudioStyle.accent)
                            Text("Keep the original, or make it yours.").font(.headline)
                            Text("Choose an image for \(store.selectedRole.title.lowercased()).\nOther slots stay just as you set them.").multilineTextAlignment(.center).foregroundStyle(StudioStyle.muted)
                            Button("Choose image…") { store.importSlot(store.selectedRole) }.buttonStyle(PrimaryButtonStyle())
                        }.frame(maxWidth: .infinity).padding(.vertical, 65)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 40)).foregroundStyle(StudioStyle.accent)
                    Text("A matching set, made by you.").font(.title2)
                    Button("Create a pack", action: store.createPack).buttonStyle(PrimaryButtonStyle())
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showRename) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Rename pack").font(.system(size: 22, weight: .semibold, design: .rounded))
                TextField("Pack name", text: $draftName).textFieldStyle(.plain)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Pack name").onSubmit { saveName() }
                HStack {
                    Spacer()
                    Button("Cancel") { showRename = false }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                    Button("Save name", action: saveName).buttonStyle(PrimaryButtonStyle())
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(28).frame(width: 390).background(StudioStyle.background)
                .foregroundStyle(StudioStyle.ink).tint(StudioStyle.accent)
        }
        .sheet(isPresented: $showDelete) {
            ThemedConfirmation(
                title: "Remove pack?", itemName: store.selectedPack?.name,
                message: "This removes the pack and its settings. Your original imported files stay untouched.",
                confirmTitle: "Remove pack",
                cancel: { showDelete = false },
                confirm: { showDelete = false; store.deletePack() }
            )
        }
    }
    private func saveName() {
        guard !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.renamePack(draftName); showRename = false
    }

}
