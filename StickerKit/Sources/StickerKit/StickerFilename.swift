import Foundation

/// The sticker's metadata, encoded in its filename so the file is the whole
/// record and iCloud has one thing to sync:
///
///     2026-09-19T08-05-11Z-a1b2c3d4-border-408.png
///     ─────────┬────────── ───┬──── ──┬─── ─┬─ ─┬─
///        created (UTC)       id     border size format
///
/// Dashes replace the colons of ISO 8601 because iCloud Drive surfaces these
/// files in Finder, where colons are not allowed.
public struct StickerFilename: Sendable, Hashable {
    public var createdAt: Date
    public var id: String
    public var hasBorder: Bool
    public var size: Int
    public var format: StickerFormat

    public init(createdAt: Date, id: String, hasBorder: Bool, size: Int, format: StickerFormat) {
        // Second precision is what the name can carry; round now so the
        // value round-trips exactly.
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
        self.id = id
        self.hasBorder = hasBorder
        self.size = size
        self.format = format
    }

    /// A name for a sticker being created now, with a fresh ID.
    public static func make(hasBorder: Bool, size: Int, format: StickerFormat, createdAt: Date = .now) -> StickerFilename {
        StickerFilename(createdAt: createdAt, id: Self.randomID(), hasBorder: hasBorder, size: size, format: format)
    }

    public var string: String {
        let c = Self.utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: createdAt)
        let stamp = String(
            format: "%04d-%02d-%02dT%02d-%02d-%02dZ",
            c.year!, c.month!, c.day!, c.hour!, c.minute!, c.second!
        )
        return "\(stamp)-\(id)\(hasBorder ? "-border" : "")-\(size).\(format.fileExtension)"
    }

    public init?(parsing name: String) {
        let pattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})Z-([0-9a-f]{8})(-border)?-(\d+)\.([A-Za-z]+)$/
        guard let match = name.wholeMatch(of: pattern),
              let format = StickerFormat(fileExtension: String(match.10)),
              let size = Int(match.9)
        else { return nil }

        var components = DateComponents()
        components.year = Int(match.1)
        components.month = Int(match.2)
        components.day = Int(match.3)
        components.hour = Int(match.4)
        components.minute = Int(match.5)
        components.second = Int(match.6)
        guard let date = Self.utc.date(from: components) else { return nil }

        self.init(createdAt: date, id: String(match.7), hasBorder: match.8 != nil, size: size, format: format)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func randomID() -> String {
        String(format: "%08x", UInt32.random(in: .min ... .max))
    }
}
