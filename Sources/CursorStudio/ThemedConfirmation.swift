import SwiftUI

struct ThemedConfirmation: View {
    let title: String
    let itemName: String?
    let message: String
    let confirmTitle: String
    var symbol = "trash"
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 22, weight: .medium))
                    .foregroundStyle(StudioStyle.accent)
                Text(title).font(.system(size: 22, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let itemName {
                Text(itemName).font(.system(size: 13, weight: .medium))
                    .lineLimit(3).help(itemName)
            }
            Text(message).font(.system(size: 13)).foregroundStyle(StudioStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: cancel).buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(action: confirm) { Label(confirmTitle, systemImage: symbol) }
                    .buttonStyle(PrimaryButtonStyle())
            }.font(.system(size: 12, weight: .semibold)).padding(.top, 4)
        }.padding(26).frame(width: 390)
            .background(StudioStyle.background).foregroundStyle(StudioStyle.ink)
            .tint(StudioStyle.accent).preferredColorScheme(.light)
    }
}
