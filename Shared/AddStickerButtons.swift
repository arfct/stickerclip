import PhotosUI
import StickerKit
import SwiftUI
import UIKit

/// The three ways into the library — paste, files, photos — as plain text
/// buttons. Shared by the Messages extension and the app so the surfaces
/// cannot drift apart.

/// UIKit's paste control, wrapped.
///
/// SwiftUI's `PasteButton` exposes only `tint`, which colours the whole
/// capsule, so it cannot be made to match a plain text button.
/// `UIPasteControl.Configuration` separates background from foreground, which
/// is what "no fill, label-coloured text" needs.
///
/// Still the system control rather than a `Button` reading `UIPasteboard`:
/// that is what reads the clipboard without an "Allow Paste?" prompt on every
/// tap.
struct PasteStickerButton: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        PasteControl { providers in
            Task { await library.add(providers) }
        }
        // Not a Button, so it takes the effect directly rather than a style.
        // Wider than tall now it carries a label, so a capsule.
        .individualGlassEffect(in: .capsule)
        .disabled(!library.isReady)
    }
}

struct PasteControl: UIViewRepresentable {
    let onPaste: @MainActor ([NSItemProvider]) -> Void

    func makeUIView(context: Context) -> PasteControlHost {
        let host = PasteControlHost()
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconAndLabel
        configuration.baseBackgroundColor = .systemBackground
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .capsule
        let control = UIPasteControl(configuration: configuration)
        // A view is a responder and this one is in the chain, so it is a
        // target the control will actually deliver to.
        control.target = host
        control.translatesAutoresizingMaskIntoConstraints = false
        host.control = control
        host.addSubview(control)
        // Fixed to the standard height and centred; its width follows the
        // label, and the host reports that as its own size.
        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: GlassMetrics.button),
            control.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: host.centerYAnchor),
        ])
        return host
    }

    func updateUIView(_ host: PasteControlHost, context: Context) {
        host.onPaste = onPaste
    }

    // Pinned to the standard control size so it matches the glass buttons
    // beside it; the control fills the host, so it takes this size too.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PasteControlHost, context: Context) -> CGSize? {
        uiView.intrinsicContentSize
    }
}

final class PasteControlHost: UIView {
    var onPaste: @MainActor ([NSItemProvider]) -> Void = { _ in }
    var control: UIPasteControl?

    override var intrinsicContentSize: CGSize {
        // Never zero: a zero here is a control SwiftUI lays out as nothing.
        let width = control?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width ?? 0
        return CGSize(width: max(width, GlassMetrics.button), height: GlassMetrics.button)
    }

    // Answer and do nothing else: the system polls this constantly while the
    // control is on screen, and often with an empty array.
    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool { true }

    override func paste(itemProviders: [NSItemProvider]) { onPaste(itemProviders) }
}

/// Photos and Files behind one ellipsis menu.
///
/// Images arrive from Photos as data, so HEIC and the rest are whatever the
/// renderer can decode rather than whatever Photos exports; the importer
/// handles the security-scoped URLs the file picker hands back.
struct AddStickerMenu: View {
    @Environment(LibraryModel.self) private var library
    @State private var photos: [PhotosPickerItem] = []
    @State private var choosingPhotos = false
    @State private var choosingFiles = false

    var body: some View {
        Menu {
            Button("Photos", systemImage: "photo.on.rectangle") { choosingPhotos = true }
            Button("Files", systemImage: "folder") { choosingFiles = true }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: GlassMetrics.button, height: GlassMetrics.button)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .individualGlassEffect(in: .circle)
        .accessibilityLabel("Add a sticker")
        .disabled(!library.isReady)
        .photosPicker(isPresented: $choosingPhotos, selection: $photos, matching: .images)
        .fileImporter(isPresented: $choosingFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            Task { await library.add(urls.map { .file($0) }) }
        }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            photos = []
            Task {
                var sources: [StickerSource] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        sources.append(.image(data))
                    }
                }
                await library.add(sources)
            }
        }
    }
}
