import Foundation
import UniformTypeIdentifiers

/// One sticker in the library. The file is the record; every field here is
/// recoverable from the URL, so nothing can drift out of sync with the file.
public struct Sticker: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let createdAt: Date
    public let hasBorder: Bool
    /// Rendered edge length in points; one of `StickerSize.all`.
    public let size: Int
    public let format: StickerFormat

    public init(id: String, url: URL, createdAt: Date, hasBorder: Bool, size: Int, format: StickerFormat) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.hasBorder = hasBorder
        self.size = size
        self.format = format
    }
}

/// The sticker envelope Messages accepts: 300–618 points square, under 500 KB.
public enum StickerSize {
    public static let all = [516, 408, 300, 192, 144, 96]
    public static let `default` = 408
    public static let maxBytes = 500 * 1024
}

/// The three encodings Messages will show as a sticker.
public enum StickerFormat: String, Sendable, CaseIterable, Hashable {
    case png
    case jpeg = "jpg"
    case gif

    public var fileExtension: String { rawValue }

    public var utType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .gif: .gif
        }
    }

    public init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        case "gif": self = .gif
        default: return nil
        }
    }

    /// Identifies the encoding from the first bytes, independent of whatever
    /// name or type identifier the source claimed.
    public init?(sniffing data: Data) {
        guard data.count >= 4 else { return nil }
        let head = [UInt8](data.prefix(4))
        switch (head[0], head[1], head[2], head[3]) {
        case (0x89, 0x50, 0x4E, 0x47): self = .png
        case (0xFF, 0xD8, _, _): self = .jpeg
        case (0x47, 0x49, 0x46, 0x38): self = .gif
        default: return nil
        }
    }
}
