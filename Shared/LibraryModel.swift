import Foundation
import StickerKit
import SwiftUI

/// The sticker library as the UI sees it, for every surface. Owns the store
/// and importer for this process and keeps a main-actor snapshot of the
/// folder; mutations go through here so the snapshot follows.
@MainActor @Observable
final class LibraryModel {
    private(set) var location: LibraryLocation?
    private(set) var stickers: [Sticker] = []
    private(set) var skipped: [URL] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    private(set) var lastError: String?

    /// The sticker being worked on, if any. It is rendered to a scratch file
    /// and only enters the library when committed — on exit, or when another
    /// paste replaces it.
    private(set) var draft: DraftSticker?

    /// How new stickers are rendered. Remembered across launches and shared
    /// with the extensions through the App Group defaults.
    var options: StickerRenderer.Options {
        didSet { Self.save(options) }
    }

    private var store: StickerStore?
    private var importer: StickerImporter?

    init() {
        options = Self.loadOptions()
    }

    var isReady: Bool { store != nil }

    func load() async {
        if store == nil {
            let location = await LibraryLocation.resolve()
            let store = StickerStore(directory: location.stickersDirectory)
            self.location = location
            self.store = store
            importer = StickerImporter(store: store)
        }
        await refresh()
    }

    func refresh() async {
        guard let store else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let listing = try await store.list()
            stickers = listing.stickers
            skipped = listing.skipped
        } catch {
            Diagnostics.log("list failed: \(Diagnostics.describe(error))")
            lastError = error.localizedDescription
        }
    }

    /// Item providers from a paste, drop, or share sheet. Reduced to sources
    /// here on the main actor — providers are not `Sendable` — then imported.
    @discardableResult
    func add(_ providers: [NSItemProvider]) async -> [Sticker] {
        let sources = await StickerImporter.sources(from: providers)
        return await add(sources)
    }

    /// One source opens the editor; several are saved straight away, since
    /// there is one editor and no sensible way to queue it.
    @discardableResult
    func add(_ sources: [StickerSource]) async -> [Sticker] {
        guard let importer, !sources.isEmpty else { return [] }
        isImporting = true
        defer { isImporting = false }

        // Whatever was being edited is kept, not dropped, when something new
        // arrives.
        await commitDraft()

        if sources.count == 1, let source = sources.first {
            do {
                draft = try await importer.draft(source, options: options)
            } catch {
                report(error)
            }
            return []
        }

        let results = await importer.import(sources, options: options)
        for case .failure(let error) in results { report(error) }
        await refresh()
        return results.compactMap { try? $0.get() }
    }

    // MARK: - Draft

    /// Re-renders the draft with new options. The choice is remembered, so
    /// the next sticker starts the way this one ended.
    func updateDraft(_ options: StickerRenderer.Options) async {
        guard let importer, let current = draft else { return }
        self.options = options
        do {
            draft = try await importer.redraft(current, options: options)
        } catch {
            report(error)
        }
    }

    func commitDraft() async {
        guard let importer, let current = draft else { return }
        draft = nil
        do {
            _ = try await importer.commit(current)
            await refresh()
        } catch {
            report(error)
        }
    }

    func discardDraft() async {
        guard let importer, let current = draft else { return }
        draft = nil
        await importer.discard(current)
    }

    func remove(_ toRemove: [Sticker]) async {
        guard let store else { return }
        for sticker in toRemove {
            do { try await store.remove(sticker) } catch { lastError = error.localizedDescription }
        }
        await refresh()
    }

    func clearError() { lastError = nil }

    private func report(_ error: Error) {
        Diagnostics.log("import failed: \(Diagnostics.describe(error))")
        lastError = Self.describe(error)
    }

    // MARK: - Options persistence

    private static let defaults = UserDefaults(suiteName: Identifiers.appGroup) ?? .standard

    private static func loadOptions() -> StickerRenderer.Options {
        var options = StickerRenderer.Options()
        if defaults.object(forKey: "showBorder") != nil { options.hasBorder = defaults.bool(forKey: "showBorder") }
        let size = defaults.integer(forKey: "stickerSize")
        if StickerSize.all.contains(size) { options.size = size }
        return options
    }

    private static func save(_ options: StickerRenderer.Options) {
        defaults.set(options.hasBorder, forKey: "showBorder")
        defaults.set(options.size, forKey: "stickerSize")
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case ImportError.nothingUsable: "Nothing on the clipboard can become a sticker."
        case ImportError.notAnImage(let url): "\(url.host() ?? "That link") didn't return an image."
        case ImportError.fetchFailed: "Couldn't download that image."
        case ImportError.unreadableFile: "Couldn't read that file."
        case ImportError.undecodable, StickerRenderer.Error.undecodable: "That isn't an image Stickerclip can read."
        case StickerRenderer.Error.emptyText: "There's no text to make a sticker from."
        // Anything else carries the system's own wording, which named the
        // flat-container problem when nothing else did.
        default: (error as NSError).localizedDescription
        }
    }
}
