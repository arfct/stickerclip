import Foundation

/// Where the sticker library lives for this process.
///
/// Resolution order: the iCloud ubiquity container when an account is signed
/// in and will accept writes, else the App Group container shared by the app
/// and its extensions, else the process's own Application Support. The last
/// case only happens without entitlements — unit tests — and keeps the store
/// usable there.
public enum LibraryLocation: Sendable, Equatable {
    case iCloud(URL)
    case appGroup(URL)
    case processLocal(URL)

    /// The folder holding the sticker files.
    public var stickersDirectory: URL {
        switch self {
        // The container declares NSUbiquitousContainerSupportedFolderLevels
        // as None, so its document scope is flat and a subfolder is refused.
        // Stickers sit directly in Documents, which is also what the user
        // sees in the Files app.
        case .iCloud(let url): url.appendingPathComponent("Documents", isDirectory: true)
        case .appGroup(let url), .processLocal(let url): url.appendingPathComponent("Stickers", isDirectory: true)
        }
    }

    public var isSynced: Bool {
        if case .iCloud = self { return true }
        return false
    }

    /// Resolves off the main actor: `url(forUbiquityContainerIdentifier:)` can
    /// block while iCloud sets the container up on first use.
    ///
    /// `preferringCloud` is false until the iCloud work lands, because a
    /// ubiquity container cannot be read with plain `FileManager` calls:
    /// `contentsOfDirectory` on one fails with POSIX 11, "Resource deadlock
    /// avoided". Listing an iCloud folder needs `NSFileCoordinator` and
    /// `NSMetadataQuery`, which is P5 in docs/plans/2026-09-19-rebuild.md.
    /// Until then the library is local and every other surface can be built
    /// against it.
    public static func resolve(preferringCloud: Bool = false) async -> LibraryLocation {
        await Task.detached(priority: .userInitiated) {
            // FileManager.default is documented thread-safe; an injected
            // instance would not be Sendable across this boundary.
            let fileManager = FileManager.default
            if preferringCloud, let cloud = fileManager.url(forUbiquityContainerIdentifier: Identifiers.iCloudContainer) {
                let location = LibraryLocation.iCloud(cloud)
                if location.prepare() {
                    Diagnostics.log("location=iCloud \(location.stickersDirectory.path)")
                    return location
                }
                Diagnostics.log("iCloud container unusable at \(location.stickersDirectory.path)")
            }
            if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Identifiers.appGroup) {
                let local = LibraryLocation.appGroup(group.appendingPathComponent("Library/Application Support", isDirectory: true))
                if local.prepare() {
                    Diagnostics.log("location=appGroup \(local.stickersDirectory.path)")
                    return local
                }
                Diagnostics.log("app group unusable at \(local.stickersDirectory.path)")
            } else {
                Diagnostics.log("no app group container for \(Identifiers.appGroup)")
            }
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            Diagnostics.log("location=processLocal \(support.path)")
            return .processLocal(support)
        }.value
    }

    /// Creates the folder, reporting whether this location can actually hold
    /// the library, so a container that will not have us falls back instead of
    /// putting an error in the user's face.
    ///
    /// Note this is necessary but not sufficient for iCloud: `createDirectory`
    /// succeeds on a ubiquity container that later refuses to be listed.
    @discardableResult
    public func prepare() -> Bool {
        do {
            try FileManager.default.createDirectory(at: stickersDirectory, withIntermediateDirectories: true)
            return true
        } catch {
            Diagnostics.log("prepare failed: \(Diagnostics.describe(error))")
            return false
        }
    }
}
