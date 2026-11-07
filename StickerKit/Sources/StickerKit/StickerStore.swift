import Foundation

/// The sticker library on disk: one folder of image files, nothing else.
///
/// Every read tolerates what it finds. A file that isn't a sticker is reported
/// in `Listing.skipped`, never thrown on — the previous app force-decoded every
/// file in its folder and one stray file took the extension down.
public actor StickerStore {
    public nonisolated let directory: URL

    public struct Listing: Sendable {
        /// Newest first.
        public var stickers: [Sticker] = []
        /// Files in the folder that could not be read as stickers.
        public var skipped: [URL] = []
    }

    public init(directory: URL) {
        self.directory = directory
    }

    public func list() throws -> Listing {
        try ensureDirectory()
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .creationDateKey, .contentModificationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        )

        var listing = Listing()
        for url in urls {
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isDirectory == true { continue }
            if let sticker = Self.sticker(at: url, fallbackDate: values?.creationDate ?? values?.contentModificationDate) {
                listing.stickers.append(sticker)
            } else {
                listing.skipped.append(url)
            }
        }
        listing.stickers.sort { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
        return listing
    }

    /// Writes already-rendered sticker bytes under a fresh name.
    @discardableResult
    public func add(_ data: Data, format: StickerFormat, hasBorder: Bool, size: Int, createdAt: Date = .now) throws -> Sticker {
        try ensureDirectory()
        let name = StickerFilename.make(hasBorder: hasBorder, size: size, format: format, createdAt: createdAt)
        let url = directory.appendingPathComponent(name.string)
        try data.write(to: url, options: .atomic)
        return Sticker(name, at: url)
    }

    public func remove(_ sticker: Sticker) throws {
        try FileManager.default.removeItem(at: sticker.url)
    }

    // MARK: - Reading

    /// A sticker for a file, or nil if the file is not an image we show.
    ///
    /// Names in the current format carry their own metadata. Names from the
    /// old app (`sticker-border-371011.png`) are still listed, from file dates,
    /// so nothing disappears before the migrator has renamed it.
    static func sticker(at url: URL, fallbackDate: Date?) -> Sticker? {
        let name = url.lastPathComponent
        if let parsed = StickerFilename(parsing: name) {
            return Sticker(parsed, at: url)
        }
        guard let format = StickerFormat(fileExtension: url.pathExtension) else { return nil }
        let stem = url.deletingPathExtension().lastPathComponent
        return Sticker(
            id: stem,
            url: url,
            createdAt: fallbackDate ?? .distantPast,
            hasBorder: stem.contains("-border"),
            size: StickerSize.default,
            format: format
        )
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

extension Sticker {
    init(_ name: StickerFilename, at url: URL) {
        self.init(
            id: name.id,
            url: url,
            createdAt: name.createdAt,
            hasBorder: name.hasBorder,
            size: name.size,
            format: name.format
        )
    }
}
