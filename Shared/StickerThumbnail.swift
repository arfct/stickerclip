import StickerKit
import SwiftUI

/// A sticker's image, decoded off the main actor and downsampled to the cell.
/// Used by the app and share extension; Messages uses `MSStickerView` so the
/// system handles peel and drag.
struct StickerThumbnail: View {
    let sticker: Sticker
    var edge: CGFloat = 100

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
            }
        }
        .frame(width: edge, height: edge)
        .task(id: sticker.url) {
            image = await Self.thumbnail(for: sticker.url, edge: edge)
        }
    }

    nonisolated static func thumbnail(for url: URL, edge: CGFloat) async -> UIImage? {
        let scale = await MainActor.run { UIScreen.main.scale }
        return await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            let target = CGSize(width: edge * scale, height: edge * scale)
            return await image.byPreparingThumbnail(ofSize: target) ?? image
        }.value
    }
}
