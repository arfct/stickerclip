import Foundation
import os
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import StickerKit

/// Answers requests from canned responses keyed by URL, so remote fetches are
/// tested without a network. Keyed, and locked, because Swift Testing runs
/// tests in parallel and they all share this class.
final class StubURLProtocol: URLProtocol {
    static let responses = OSAllocatedUnfairLock<[URL: (HTTPURLResponse, Data)]>(initialState: [:])

    static func stub(_ url: URL, status: Int, contentType: String, body: Data) {
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": contentType]
        )!
        responses.withLock { $0[url] = (response, body) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let (response, data) = Self.responses.withLock({ $0[url] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct StickerImporterTests {
    let png: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }.pngData()!
    }()

    func makeImporter() -> (StickerImporter, StickerStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StickerImporterTests-\(UUID().uuidString)", isDirectory: true)
        let store = StickerStore(directory: dir)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return (StickerImporter(store: store, session: URLSession(configuration: config)), store)
    }

    // MARK: Item providers → sources

    @Test func emptyProvidersYieldNoSources() async {
        // The system polls paste handlers with empty arrays; that is not an error.
        let sources = await StickerImporter.sources(from: [])
        #expect(sources.isEmpty)
    }

    @Test func imageProviderBecomesImageBytes() async {
        let provider = NSItemProvider(item: png as NSData, typeIdentifier: UTType.png.identifier)
        let sources = await StickerImporter.sources(from: [provider])
        #expect(sources == [.image(png)])
    }

    @Test func textProviderBecomesText() async {
        let provider = NSItemProvider(object: "hello" as NSString)
        let sources = await StickerImporter.sources(from: [provider])
        #expect(sources == [.text("hello")])
    }

    @Test func webURLProviderBecomesRemote() async {
        let url = URL(string: "https://example.com/pic.png")!
        let provider = NSItemProvider(object: url as NSURL)
        let sources = await StickerImporter.sources(from: [provider])
        #expect(sources == [.remote(url)])
    }

    @Test func fileProviderIsUsable() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try png.write(to: file)
        let provider = try #require(NSItemProvider(contentsOf: file))
        let sources = await StickerImporter.sources(from: [provider])
        #expect(sources.count == 1)
        let (importer, _) = makeImporter()
        _ = try await importer.import(sources[0], options: .init(hasBorder: false))
    }

    // MARK: Sources → stickers

    @Test func importsTextIntoTheStore() async throws {
        let (importer, store) = makeImporter()
        let sticker = try await importer.import(.text("Yo"), options: .init(size: 300, hasBorder: true))
        let listing = try await store.list()
        #expect(listing.stickers == [sticker])
        #expect(sticker.format == .png)
        #expect(sticker.hasBorder)
    }

    @Test func importsRemoteImage() async throws {
        let url = URL(string: "https://example.com/a.png")!
        StubURLProtocol.stub(url, status: 200, contentType: "image/png", body: png)
        let (importer, _) = makeImporter()
        let sticker = try await importer.import(.remote(url), options: .init(hasBorder: false))
        #expect(sticker.format == .png)
    }

    @Test func rejectsRemoteContentThatIsNotAnImage() async {
        let url = URL(string: "https://example.com/page")!
        StubURLProtocol.stub(url, status: 200, contentType: "text/html", body: Data("<html>".utf8))
        let (importer, _) = makeImporter()
        await #expect(throws: ImportError.self) {
            try await importer.import(.remote(url), options: .init())
        }
    }

    @Test func rejectsFailedFetch() async {
        let url = URL(string: "https://example.com/missing.png")!
        StubURLProtocol.stub(url, status: 404, contentType: "image/png", body: Data())
        let (importer, _) = makeImporter()
        await #expect(throws: ImportError.self) {
            try await importer.import(.remote(url), options: .init())
        }
    }

    @Test func reportsEachItemSeparately() async throws {
        let (importer, store) = makeImporter()
        let results = await importer.import([.text("ok"), .image(Data("junk".utf8))], options: .init())
        #expect(results.count == 2)
        #expect((try? results[0].get()) != nil)
        #expect((try? results[1].get()) == nil)
        #expect(try await store.list().stickers.count == 1)
    }
}

struct DraftStickerTests {
    let png: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 140), format: format).image { ctx in
            UIColor.systemIndigo.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 140))
        }.pngData()!
    }()

    func makeImporter() -> (StickerImporter, StickerStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DraftTests-\(UUID().uuidString)", isDirectory: true)
        let store = StickerStore(directory: dir)
        return (StickerImporter(store: store), store)
    }

    @Test func draftingDoesNotTouchTheLibrary() async throws {
        let (importer, store) = makeImporter()
        let draft = try await importer.draft(.image(png), options: .init(size: 408, hasBorder: true))
        #expect(FileManager.default.fileExists(atPath: draft.url.path))
        #expect(try await store.list().stickers.isEmpty)
    }

    @Test func committingMovesItIntoTheLibraryAndClearsTheDraft() async throws {
        let (importer, store) = makeImporter()
        let draft = try await importer.draft(.image(png), options: .init(size: 300, hasBorder: true))
        let sticker = try await importer.commit(draft)

        #expect(try await store.list().stickers == [sticker])
        #expect(sticker.hasBorder)
        #expect(sticker.size == draft.size)
        #expect(!FileManager.default.fileExists(atPath: draft.url.path))
    }

    @Test func discardingLeavesNothingBehind() async throws {
        let (importer, store) = makeImporter()
        let draft = try await importer.draft(.image(png), options: .init())
        await importer.discard(draft)
        #expect(!FileManager.default.fileExists(atPath: draft.url.path))
        #expect(try await store.list().stickers.isEmpty)
    }

    @Test func redraftingKeepsIdentityAndChangesTheFile() async throws {
        let (importer, _) = makeImporter()
        let bordered = try await importer.draft(.image(png), options: .init(size: 408, hasBorder: true))
        let plain = try await importer.redraft(bordered, options: .init(size: 408, hasBorder: false))

        #expect(plain.id == bordered.id)
        #expect(plain.hasBorder == false)
        // A fresh URL, because MSStickerView caches by path.
        #expect(plain.url != bordered.url)
        #expect(!FileManager.default.fileExists(atPath: bordered.url.path))
        #expect(FileManager.default.fileExists(atPath: plain.url.path))
    }
}
