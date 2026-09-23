import SwiftUI
import AppKit

struct ThemedMenuItem: Identifiable {
    var id: String { title }
    var title: String
    var symbol: String = ""
    var image: NSImage? = nil
    var disabled = false
    var destructive = false
    var action: () -> Void
}

// App-owned popovers give both the trigger and the choices our botanical colors.
struct ThemedMenu: View {
    var title: String = ""
    var symbol = "ellipsis"
    var accessibilityName = "Actions"
    var items: [ThemedMenuItem]
    @State private var presented = false
    @State private var search = ""
    var body: some View {
        Button { search = ""; presented.toggle() } label: {
            HStack(spacing: 8) {
                if !title.isEmpty { Text(title) }
                Image(systemName: symbol)
            }
        }.buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(title.isEmpty ? accessibilityName : title)
            .popover(isPresented: $presented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if !title.isEmpty {
                        Text(title).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 8)
                    }
                    if items.count > 6 {
                        TextField("Find a cursor", text: $search).textFieldStyle(.plain)
                            .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Find a library cursor")
                    }
                    if filteredIndices.count > 6 {
                        ScrollView { menuRows }.frame(height: 310)
                    } else {
                        menuRows.fixedSize(horizontal: false, vertical: true)
                    }
                }.font(.system(size: 12)).padding(8)
                    .frame(width: title.isEmpty ? 220 : 270)
                    .foregroundStyle(StudioStyle.ink).background(StudioStyle.background)
                    .tint(StudioStyle.accent).preferredColorScheme(.light)
                    .onExitCommand { presented = false }
            }
    }

    private var filteredIndices: [Int] {
        items.indices.filter { search.isEmpty || items[$0].title.localizedCaseInsensitiveContains(search) }
    }

    private var menuRows: some View {
        VStack(spacing: 2) {
            ForEach(filteredIndices, id: \.self) { index in
                let item = items[index]
                Button { presented = false; item.action() } label: {
                    HStack(spacing: 8) {
                        if let image = item.image {
                            Image(nsImage: image).resizable().scaledToFit().frame(width: 28, height: 28)
                        } else if !item.symbol.isEmpty {
                            Image(systemName: item.symbol).frame(width: 18)
                        }
                        Text(item.title).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(ThemedMenuRowStyle(destructive: item.destructive)).disabled(item.disabled)
            }
            if filteredIndices.isEmpty {
                Text(items.isEmpty ? "Import an image to get started." : "No matching cursors")
                    .foregroundStyle(StudioStyle.muted).padding(10)
            }
        }
    }

}

private struct ThemedMenuRowStyle: ButtonStyle {
    var destructive: Bool
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(label: configuration.label, pressed: configuration.isPressed, destructive: destructive, enabled: enabled)
    }
    private struct MenuRow: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        let destructive: Bool
        let enabled: Bool
        @State private var hovering = false
        var body: some View {
            label.padding(.horizontal, 10).padding(.vertical, 8)
                .foregroundStyle(destructive ? Color(red: 0.58, green: 0.29, blue: 0.20) : StudioStyle.ink)
                .background(hovering || pressed ? StudioStyle.yellow.opacity(0.55) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .opacity(enabled ? 1 : 0.4).onHover { hovering = $0 }
        }
    }
}
