import Messages
import StickerKit
import SwiftUI

/// `MSStickerView` in SwiftUI. The system view gives tap-to-insert and
/// peel-to-drag for free, which is why the grid in Messages uses it rather
/// than `StickerThumbnail`.
struct MessagesStickerView: UIViewRepresentable {
    let url: URL

    init(sticker: Sticker) { url = sticker.url }
    init(draft: DraftSticker) { url = draft.url }

    func makeUIView(context: Context) -> MSStickerView {
        let view = MSStickerView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: MSStickerView, context: Context) {
        guard view.sticker?.imageFileURL != url else { return }
        // A file that will not load as a sticker leaves the cell empty rather
        // than failing; the store already reports such files separately.
        view.sticker = try? MSSticker(contentsOfFileURL: url, localizedDescription: "Sticker")
        view.startAnimating()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MSStickerView, context: Context) -> CGSize? {
        // Fill whatever the grid offers; intrinsic sticker size is irrelevant here.
        CGSize(width: proposal.width ?? 100, height: proposal.height ?? 100)
    }
}
