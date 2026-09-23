import SwiftUI
import AppKit

struct CursorEditor: View {
    @EnvironmentObject var store: CursorStore
    let item: CursorItem
    let image: NSImage
    var inPack = false
    @State private var showPoint = true
    @State private var previewDark = false
    @State private var name = ""
    @State private var showDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                TextField("Cursor name", text: $name).textFieldStyle(.plain).font(.system(size: 20, weight: .semibold, design: .rounded))
                    .onSubmit { rename() }.onChange(of: name) { _, value in if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { rename() } }
                    .accessibilityLabel("Cursor name")
                if !inPack { Button { store.update { $0.isFavorite.toggle() } } label: { Image(systemName: item.isFavorite ? "heart.fill" : "heart").font(.system(size: 16)).foregroundStyle(StudioStyle.accent) }
                    .buttonStyle(.plain).help(item.isFavorite ? "Remove from favorites" : "Add to favorites") }
                Menu {
                    Button("Export PNG…", action: store.exportSelected)
                    Button(inPack ? "Use Original for This Slot…" : "Remove Cursor…", role: .destructive) { showDelete = true }
                } label: { Image(systemName: "ellipsis").font(.system(size: 16)) }.menuStyle(.borderlessButton).fixedSize().help("Cursor actions")
            }
            VStack(spacing: 0) {
                HStack {
                    Text("THE LITTLE DETAILS").font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(StudioStyle.muted)
                    Spacer()
                    Button { previewDark.toggle() } label: { Image(systemName: previewDark ? "sun.max" : "moon").font(.system(size: 12)) }
                        .buttonStyle(.plain).foregroundStyle(StudioStyle.muted).help("Switch preview background")
                }.padding(18)
                GeometryReader { geometry in
                    let longest: CGFloat = 154
                    let ratio = image.size.width / image.size.height
                    let width = ratio >= 1 ? longest : longest * ratio
                    let height = ratio >= 1 ? longest / ratio : longest
                    let origin = CGPoint(x: (geometry.size.width - width) / 2, y: (geometry.size.height - height) / 2)
                    ZStack(alignment: .topLeading) {
                        Checkerboard(dark: previewDark)
                        Image(nsImage: image).resizable().interpolation(.high).frame(width: width, height: height).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        if showPoint {
                            Circle().fill(StudioStyle.accent).frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .overlay(Circle().stroke(StudioStyle.accent.opacity(0.25), lineWidth: 7))
                                .position(x: origin.x + item.hotspotX * width, y: origin.y + item.hotspotY * height)
                        }
                    }.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            showPoint = true
                            store.update {
                                $0.hotspotX = min(max((value.location.x - origin.x) / width, 0), 0.999)
                                $0.hotspotY = min(max((value.location.y - origin.y) / height, 0), 0.999)
                            }
                        })
                        .accessibilityLabel("Click point preview")
                        .accessibilityHint("Click or drag to position the click point. Keyboard users can use the horizontal and vertical click point sliders below.")
                }.frame(height: 196)
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap")
                    Text("Click the image to set its click point")
                }.font(.system(size: 10)).foregroundStyle(StudioStyle.muted).frame(maxWidth: .infinity).padding(14)
            }.background(.white, in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(StudioStyle.line))

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Pointer size").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int(item.size)) pt").font(.system(size: 11, design: .monospaced)).foregroundStyle(StudioStyle.muted)
                }
                HStack(spacing: 12) {
                    Image(systemName: "cursorarrow").font(.system(size: 10))
                    Slider(value: Binding(get: { item.size }, set: { value in store.update { $0.size = value } }), in: 16...64, step: 1).accessibilityLabel("Pointer size")
                    Image(systemName: "cursorarrow").font(.system(size: 18))
                }.foregroundStyle(StudioStyle.muted)
                HStack {
                    Toggle("Show click point", isOn: $showPoint).toggleStyle(.checkbox).font(.system(size: 11))
                    Spacer()
                    Button("Center") { store.update { $0.hotspotX = 0.5; $0.hotspotY = 0.5 } }.buttonStyle(.plain).foregroundStyle(StudioStyle.accent).font(.system(size: 11, weight: .medium))
                }
                HStack(spacing: 12) {
                    hotspotSlider("X", value: item.hotspotX) { value in store.update { $0.hotspotX = value } }
                    hotspotSlider("Y", value: item.hotspotY) { value in store.update { $0.hotspotY = value } }
                }
            }.padding(.horizontal, 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("TAKE IT FOR A SPIN").font(.system(size: 9, weight: .semibold)).tracking(1.6).foregroundStyle(StudioStyle.muted)
                CursorPlayground(cursor: item.cursor(for: image))
                    .frame(height: 88).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StudioStyle.line))
            }
            if !inPack {
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.hasUnappliedChanges ? "Changes ready to apply" : "Make it your main pointer").font(.system(size: 11, weight: .medium))
                    Text(store.systemAvailable ? "Experimental · some apps may override it" : "System apply unavailable on this Mac")
                        .font(.system(size: 9)).foregroundStyle(StudioStyle.muted)
                }
                Spacer(minLength: 0)
                Button(action: store.apply) {
                    HStack(spacing: 7) {
                        Text(store.activeID == item.id && !store.hasUnappliedChanges ? "Applied" : "Apply pointer")
                        Image(systemName: store.activeID == item.id && !store.hasUnappliedChanges ? "checkmark" : "arrow.up.right")
                    }.font(.system(size: 12, weight: .semibold))
                }.buttonStyle(PrimaryButtonStyle()).disabled(!store.systemAvailable)
            }
            }
        }.onAppear { name = item.name }
            .confirmationDialog(inPack ? "Use the original cursor for this slot?" : "Remove “\(item.name)” from your library?", isPresented: $showDelete, titleVisibility: .visible) {
                Button(inPack ? "Use Original" : "Remove Cursor", role: .destructive, action: store.deleteSelected)
            } message: { Text("Your original image file will stay untouched.") }
    }

    private func rename() {
        let value = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        if !value.isEmpty, value != item.name { store.update { $0.name = value } }
    }

    private func hotspotSlider(_ title: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 10, design: .monospaced)).foregroundStyle(StudioStyle.muted)
            Slider(value: Binding(get: { value }, set: set), in: 0...0.999).controlSize(.mini)
                .accessibilityLabel(title == "X" ? "Horizontal click point" : "Vertical click point")
        }
    }
}

struct Checkerboard: View {
    var dark: Bool
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark ? Color(white: 0.20) : Color(white: 0.985)))
            let step: CGFloat = 14
            for row in 0...Int(size.height / step) {
                for column in 0...Int(size.width / step) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step, width: step, height: step)), with: .color(dark ? .white.opacity(0.035) : .black.opacity(0.025)))
                }
            }
        }
    }
}

struct CursorPlayground: NSViewRepresentable {
    let cursor: NSCursor
    func makeNSView(context: Context) -> PlaygroundView { PlaygroundView(cursor: cursor) }
    func updateNSView(_ view: PlaygroundView, context: Context) {
        view.previewCursor = cursor
        view.window?.invalidateCursorRects(for: view)
    }
}

final class PlaygroundView: NSView {
    var previewCursor: NSCursor
    private var clicks = 0
    private var clickPoint: NSPoint?
    init(cursor: NSCursor) {
        previewCursor = cursor
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityLabel("Cursor test area. Move your pointer here and click to test.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func resetCursorRects() { addCursorRect(bounds, cursor: previewCursor) }
    override func mouseDown(with event: NSEvent) { clicks += 1; clickPoint = convert(event.locationInWindow, from: nil); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.935, green: 0.925, blue: 0.975, alpha: 1).setFill(); bounds.fill()
        if let point = clickPoint {
            NSColor(calibratedRed: 0.43, green: 0.32, blue: 0.78, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: NSRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)).fill()
        }
        let text = clicks == 0 ? "Move your pointer here. Give it a click." : "Nice click. \(clicks) little moment\(clicks == 1 ? "" : "s") of joy."
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(calibratedRed: 0.43, green: 0.37, blue: 0.57, alpha: 1)]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }
}
