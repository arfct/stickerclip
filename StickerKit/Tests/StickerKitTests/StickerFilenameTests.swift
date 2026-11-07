import Foundation
import Testing
@testable import StickerKit

struct StickerFilenameTests {
    let date = Date(timeIntervalSince1970: 1789805111) // 2026-09-19 08:05:11 UTC

    @Test func encodesEveryField() {
        let name = StickerFilename(createdAt: date, id: "a1b2c3d4", hasBorder: true, size: 408, format: .png)
        #expect(name.string == "2026-09-19T08-05-11Z-a1b2c3d4-border-408.png")
    }

    @Test func omitsBorderWhenAbsent() {
        let name = StickerFilename(createdAt: date, id: "a1b2c3d4", hasBorder: false, size: 192, format: .gif)
        #expect(name.string == "2026-09-19T08-05-11Z-a1b2c3d4-192.gif")
    }

    @Test func roundTrips() {
        let original = StickerFilename(createdAt: date, id: "deadbeef", hasBorder: true, size: 516, format: .jpeg)
        let parsed = StickerFilename(parsing: original.string)
        #expect(parsed == original)
    }

    @Test func roundsSubsecondPrecisionAway() {
        let fractional = Date(timeIntervalSince1970: 1789805111.789)
        let name = StickerFilename(createdAt: fractional, id: "00000000", hasBorder: false, size: 300, format: .png)
        #expect(StickerFilename(parsing: name.string)?.createdAt == date)
    }

    @Test func acceptsJpegSpelling() {
        let parsed = StickerFilename(parsing: "2026-09-19T08-05-11Z-a1b2c3d4-408.jpeg")
        #expect(parsed?.format == .jpeg)
    }

    @Test(arguments: [
        "sticker-border-371011.png",             // old app's format
        "2026-09-19T08-05-11Z-a1b2c3d4-408.txt", // not an image
        "2026-09-19T08-05-11Z-zzzz-408.png",     // bad id
        "notes.md",
    ])
    func rejectsForeignNames(_ name: String) {
        #expect(StickerFilename(parsing: name) == nil)
    }

    @Test func freshNamesAreUnique() {
        let a = StickerFilename.make(hasBorder: false, size: 408, format: .png, createdAt: date)
        let b = StickerFilename.make(hasBorder: false, size: 408, format: .png, createdAt: date)
        #expect(a.id != b.id)
        #expect(a.id.count == 8)
    }

    @Test func sniffsFormatFromBytes() {
        #expect(StickerFormat(sniffing: Data([0x89, 0x50, 0x4E, 0x47, 0x0D])) == .png)
        #expect(StickerFormat(sniffing: Data([0xFF, 0xD8, 0xFF, 0xE0])) == .jpeg)
        #expect(StickerFormat(sniffing: Data("GIF89a".utf8)) == .gif)
        #expect(StickerFormat(sniffing: Data("hello".utf8)) == nil)
    }
}
