import SwiftUI
import AppKit

@main
struct CursorStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = CursorStore()

    var body: some Scene {
        Window("Cute Cursor", id: "studio") {
            StudioView().environmentObject(store)
                .onAppear { delegate.store = store; NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1060, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Cursor…", action: store.chooseFiles).keyboardShortcut("o")
                Button("New Pack", action: store.createPack).keyboardShortcut("n")
                Button("Export Pack…", action: store.exportPack).disabled(store.selectedPack == nil)
                Button("Export PNG…", action: store.exportSelected).disabled(store.selected == nil)
            }
            CommandMenu("Cursor") {
                Button(store.packMode ? "Apply Pack" : "Apply Pointer", action: store.apply).keyboardShortcut(.return, modifiers: .command)
                    .disabled((store.packMode ? store.selectedPack?.cursors.isEmpty != false : store.selected == nil) || !store.systemAvailable)
                Button("System Default", action: store.restore).keyboardShortcut("r")
            }
        }
        MenuBarExtra("Cute Cursor", systemImage: "cursorarrow.rays") {
            StudioMenu().environmentObject(store)
        }
    }
}

struct StudioMenu: View {
    @EnvironmentObject var store: CursorStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(!store.hasActiveCursors ? "Original cursors" : "Custom cursors active")
        Button("Open Cute Cursor") { openWindow(id: "studio"); NSApp.activate(ignoringOtherApps: true) }
        Button("System Default", action: store.restore)
        Divider()
        Button("Quit Cute Cursor") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pendingURLs: [URL] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let url = Bundle.main.url(forResource: name, withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }
    weak var store: CursorStore? {
        didSet {
            if let store, !pendingURLs.isEmpty { let urls = pendingURLs; pendingURLs = []; store.importFiles(urls) }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if store?.hasActiveCursors == true { store?.restore() }
        if store?.hasActiveCursors == true {
            let alert = NSAlert()
            alert.messageText = "The default pointer couldn’t be restored"
            alert.informativeText = "You can keep the app open and retry, or quit. Signing out clears the custom pointer."
            alert.addButton(withTitle: "Keep Open"); alert.addButton(withTitle: "Quit Anyway")
            return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
        }
        return .terminateNow
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        if let store { store.importFiles(urls) } else { pendingURLs.append(contentsOf: urls) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
