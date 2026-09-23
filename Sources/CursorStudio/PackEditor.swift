import SwiftUI

struct PackEditor: View {
    @EnvironmentObject var store: CursorStore
    @State private var showDelete = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let pack = store.selectedPack {
                HStack {
                    TextField("Pack name", text: Binding(get: { pack.name }, set: store.renamePack))
                        .font(.system(size: 22, weight: .semibold, design: .rounded)).textFieldStyle(.plain)
                        .accessibilityLabel("Pack name")
                    Menu {
                        Button("Export Pack…", action: store.exportPack).disabled(pack.cursors.isEmpty)
                        Button("Remove Pack…", role: .destructive) { showDelete = true }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                }
                Text("\(pack.cursors.count) of 11 slots · Empty slots use your original cursors.")
                    .font(.system(size: 11)).foregroundStyle(StudioStyle.muted)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(CursorRole.allCases) { role in
                            Button { store.selectedRole = role } label: {
                                VStack(spacing: 6) {
                                    Group {
                                        if let item = pack[role], let image = store.image(for: item) {
                                            Image(nsImage: image).resizable().scaledToFit()
                                        } else { Image(systemName: role.symbol).foregroundStyle(StudioStyle.muted) }
                                    }.frame(width: 25, height: 25)
                                    Text(role.title).font(.system(size: 9)).lineLimit(1)
                                }.frame(width: 66).padding(.vertical, 9)
                                    .background(store.selectedRole == role ? StudioStyle.accent.opacity(0.12) : .white, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(store.selectedRole == role ? StudioStyle.accent : StudioStyle.line))
                            }.buttonStyle(.plain).accessibilityLabel("\(role.title), \(pack[role] == nil ? "original" : "custom")")
                        }
                    }.padding(2)
                }.scrollIndicators(.visible)
                HStack {
                    Text(store.selectedRole.title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Menu("Use from library") {
                        ForEach(store.items) { item in
                            Button(item.name) { store.assign(item, to: store.selectedRole) }
                        }
                    }.fixedSize()
                    Button("Choose image…") { store.importSlot(store.selectedRole) }
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.hasUnappliedPackChanges ? "Changes ready to apply" : "One pack. A little personality everywhere.").font(.system(size: 11, weight: .medium))
                        Text("System replacement is experimental.").font(.system(size: 10)).foregroundStyle(StudioStyle.muted)
                    }
                    Spacer()
                    Button(store.activePackID == pack.id && !store.hasUnappliedPackChanges ? "Applied ✓" : "Apply pack", action: store.applyPack)
                        .buttonStyle(PrimaryButtonStyle()).disabled(pack.cursors.isEmpty || !store.systemAvailable)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 40)).foregroundStyle(StudioStyle.accent)
                    Text("A matching set, made by you.").font(.title2)
                    Button("Create a pack", action: store.createPack).buttonStyle(PrimaryButtonStyle())
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .confirmationDialog("Remove this pack?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Remove Pack", role: .destructive, action: store.deletePack)
        } message: { Text("Your original imported files stay untouched.") }
    }
}
