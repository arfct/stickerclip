import Foundation

/// A sticker being worked on: rendered to a scratch file so it can be
/// previewed and dragged, but not yet in the library.
///
/// The scratch file matters. `MSSticker` needs a file URL, so a draft has to
/// exist on disk to be a real, draggable sticker before the user commits to
/// it. It lives outside the library folder, so an abandoned draft never shows
/// up among the saved stickers.
public struct DraftSticker: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let source: StickerSource
    public let url: URL
    public let options: StickerRenderer.Options
    public let format: StickerFormat
    /// The size actually rendered, which may be smaller than requested when
    /// the byte limit forced a step down.
    public let size: Int
    public let hasBorder: Bool
    public let byteCount: Int

    /// True when the source is passed through untouched — an animated GIF —
    /// so the border and size controls have nothing to act on.
    public var isPassthrough: Bool { format == .gif }
}

extension StickerImporter {
    /// Where drafts live: outside the library, cleared as they are committed
    /// or discarded.
    static var draftsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Drafts", isDirectory: true)
    }

    /// Renders a source for preview without touching the library.
    public func draft(_ source: StickerSource, options: StickerRenderer.Options, id: UUID = UUID()) async throws -> DraftSticker {
        let output = try await render(source, options: options)
        let directory = Self.draftsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // A new file each time: MSStickerView caches by URL, so re-rendering
        // over the same path would keep showing the previous image.
        let url = directory.appendingPathComponent("\(id.uuidString)-\(output.size)-\(output.hasBorder).\(output.format.fileExtension)")
        try output.data.write(to: url, options: .atomic)

        return DraftSticker(
            id: id, source: source, url: url, options: options, format: output.format,
            size: output.size, hasBorder: output.hasBorder, byteCount: output.data.count
        )
    }

    /// Re-renders the same draft with different options, keeping its identity.
    public func redraft(_ draft: DraftSticker, options: StickerRenderer.Options) async throws -> DraftSticker {
        let updated = try await self.draft(draft.source, options: options, id: draft.id)
        discardFile(of: draft)
        return updated
    }

    /// Moves a draft into the library.
    @discardableResult
    public func commit(_ draft: DraftSticker) async throws -> Sticker {
        let data = try Data(contentsOf: draft.url)
        let sticker = try await store.add(data, format: draft.format, hasBorder: draft.hasBorder, size: draft.size)
        discardFile(of: draft)
        return sticker
    }

    public func discard(_ draft: DraftSticker) {
        discardFile(of: draft)
    }

    private func discardFile(of draft: DraftSticker) {
        try? FileManager.default.removeItem(at: draft.url)
    }
}
