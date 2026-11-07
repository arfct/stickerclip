import Foundation
import Testing
@testable import StickerKit

struct StickerStoreTests {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    func makeStore() throws -> StickerStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StickerStoreTests-\(UUID().uuidString)", isDirectory: true)
        return StickerStore(directory: dir)
    }

    @Test func createsItsFolderOnFirstUse() async throws {
        let store = try makeStore()
        #expect(!FileManager.default.fileExists(atPath: store.directory.path))
        _ = try await store.list()
        #expect(FileManager.default.fileExists(atPath: store.directory.path))
    }

    @Test func addsListsAndRemoves() async throws {
        let store = try makeStore()
        let added = try await store.add(png, format: .png, hasBorder: true, size: 408)

        var listing = try await store.list()
        #expect(listing.stickers == [added])
        #expect(listing.skipped.isEmpty)
        #expect(added.hasBorder)
        #expect(added.size == 408)
        #expect(try Data(contentsOf: added.url) == png)

        try await store.remove(added)
        listing = try await store.list()
        #expect(listing.stickers.isEmpty)
    }

    @Test func listsNewestFirst() async throws {
        let store = try makeStore()
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let older = try await store.add(png, format: .png, hasBorder: false, size: 408, createdAt: t0)
        let newer = try await store.add(png, format: .png, hasBorder: false, size: 408, createdAt: t0 + 60)
        let listing = try await store.list()
        #expect(listing.stickers.map(\.id) == [newer.id, older.id])
    }

    @Test func skipsFilesThatAreNotStickersInsteadOfFailing() async throws {
        let store = try makeStore()
        _ = try await store.list()
        let stray = store.directory.appendingPathComponent("notes.txt")
        try Data("not a sticker".utf8).write(to: stray)
        try FileManager.default.createDirectory(at: store.directory.appendingPathComponent("sub"), withIntermediateDirectories: true)

        let listing = try await store.list()
        #expect(listing.stickers.isEmpty)
        #expect(listing.skipped == [stray])
    }

    @Test func listsOldAppFilenamesFromFileDates() async throws {
        let store = try makeStore()
        _ = try await store.list()
        let legacy = store.directory.appendingPathComponent("sticker-border-371011.png")
        try png.write(to: legacy)

        let listing = try await store.list()
        let sticker = try #require(listing.stickers.first)
        #expect(sticker.id == "sticker-border-371011")
        #expect(sticker.hasBorder)
        #expect(sticker.format == .png)
        #expect(sticker.size == StickerSize.default)
        #expect(sticker.createdAt > .distantPast)
    }
}
