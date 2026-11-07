import Foundation
import UniformTypeIdentifiers

/// Something that can become a sticker, reduced to `Sendable` values so it
/// can cross from the UI into the importer.
public enum StickerSource: Sendable, Hashable {
    case image(Data)
    case file(URL)
    case remote(URL)
    case text(String)
}

public enum ImportError: Error, Sendable {
    /// The item offered nothing an image could be made from; carries what it did offer.
    case nothingUsable(types: [String])
    case unreadableFile(URL)
    case fetchFailed(URL)
    case notAnImage(URL)
    case undecodable
}

/// Every way in — paste, Photos, Files, share sheet, drop — ends here.
public actor StickerImporter {
    let store: StickerStore
    private let session: URLSession

    public init(store: StickerStore, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    /// Renders and saves one source. Rendering is CPU work and runs here,
    /// off the main actor.
    public func `import`(_ source: StickerSource, options: StickerRenderer.Options) async throws -> Sticker {
        let output = try await render(source, options: options)
        return try await store.add(output.data, format: output.format, hasBorder: output.hasBorder, size: output.size)
    }

    /// Renders without saving, so a draft can be previewed first.
    func render(_ source: StickerSource, options: StickerRenderer.Options) async throws -> StickerRenderer.Output {
        switch source {
        case .text(let text):
            try StickerRenderer.render(text: text, options: options)
        case .image(let data):
            try StickerRenderer.render(image: data, options: options)
        case .file(let url):
            try StickerRenderer.render(image: try Self.read(url), options: options)
        case .remote(let url):
            try StickerRenderer.render(image: try await fetch(url), options: options)
        }
    }

    /// One result per source, in order; a failure in one does not stop the rest.
    public func `import`(_ sources: [StickerSource], options: StickerRenderer.Options) async -> [Result<Sticker, Error>] {
        var results: [Result<Sticker, Error>] = []
        for source in sources {
            do { results.append(.success(try await `import`(source, options: options))) }
            catch { results.append(.failure(error)) }
        }
        return results
    }

    // MARK: - Item providers

    /// Reduces item providers to sources. Main-actor because `NSItemProvider`
    /// is not `Sendable` and every provider comes from UI — a paste, a drop,
    /// a share sheet — so this runs where they already are, and only the
    /// `Sendable` results cross into the actor.
    ///
    /// Preference order per item: image bytes, then a file, then a web URL,
    /// then text. An empty provider list is an empty result, not an error —
    /// the system polls paste handlers with empty arrays.
    @MainActor public static func sources(from providers: [NSItemProvider]) async -> [StickerSource] {
        var sources: [StickerSource] = []
        for provider in providers {
            if let source = await source(from: provider) { sources.append(source) }
        }
        return sources
    }

    @MainActor static func source(from provider: NSItemProvider) async -> StickerSource? {
        let types = provider.registeredTypeIdentifiers
        if let imageType = types.first(where: { UTType($0)?.conforms(to: .image) ?? false }),
           let data = try? await provider.loadData(forTypeIdentifier: imageType) {
            return .image(data)
        }
        if provider.canLoadObject(ofClass: NSURL.self), let url = await provider.loadURL() {
            return url.isFileURL ? .file(url) : .remote(url)
        }
        if provider.canLoadObject(ofClass: NSString.self), let text = await provider.loadString() {
            return .text(text)
        }
        return nil
    }

    // MARK: - Reading

    private static func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadableFile(url) }
        return data
    }

    /// Copying an image in Safari often puts a URL on the clipboard rather
    /// than image bytes, so a URL is fetched and judged by what comes back.
    private func fetch(_ url: URL) async throws -> Data {
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode)
        else { throw ImportError.fetchFailed(url) }
        let mime = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard mime.hasPrefix("image/") || StickerFormat(sniffing: data) != nil else {
            throw ImportError.notAnImage(url)
        }
        return data
    }
}

extension NSItemProvider {
    /// The completion-handler API, awaited. Fails if the provider vends
    /// nothing for the type — callers treat that as "try the next type".
    @MainActor func loadData(forTypeIdentifier type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? ImportError.undecodable) }
            }
        }
    }

    // `loadObject(ofClass:)` is the API that reliably yields objects for
    // providers registered from objects; the value is converted to a Sendable
    // type before it crosses the continuation.

    @MainActor func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: NSURL.self) { object, _ in
                continuation.resume(returning: (object as? NSURL)?.absoluteURL)
            }
        }
    }

    @MainActor func loadString() async -> String? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: NSString.self) { object, _ in
                continuation.resume(returning: (object as? NSString).map(String.init))
            }
        }
    }
}
