import Foundation
import Testing
@testable import StickerKit

struct LibraryLocationTests {
    @Test func resolvesSomewhereWithoutEntitlements() async {
        // The test process has no App Group or iCloud entitlement, so this
        // exercises the last fallback: the store must still have a home.
        let location = await LibraryLocation.resolve()
        #expect(location.stickersDirectory.lastPathComponent == "Stickers")
        #expect(location.isSynced == false)
    }

    @Test func iCloudLocationIsFlatUnderDocuments() {
        // The container declares no supported folder levels, so a subfolder
        // of Documents cannot be created there.
        let container = URL(fileURLWithPath: "/tmp/ubiquity", isDirectory: true)
        let location = LibraryLocation.iCloud(container)
        #expect(location.stickersDirectory.path == "/tmp/ubiquity/Documents")
        #expect(location.isSynced)
    }

    @Test func prepareReportsWhetherTheFolderCanBeMade() throws {
        let usable = LibraryLocation.appGroup(
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        #expect(usable.prepare())
        #expect(FileManager.default.fileExists(atPath: usable.stickersDirectory.path))

        // /dev is not writable, so this stands in for a container iCloud
        // hands back but will not accept writes to.
        #expect(LibraryLocation.appGroup(URL(fileURLWithPath: "/dev/null")).prepare() == false)
    }

    @Test func appGroupLocationIsNotUnderDocuments() {
        let container = URL(fileURLWithPath: "/tmp/group", isDirectory: true)
        let location = LibraryLocation.appGroup(container)
        #expect(location.stickersDirectory.path == "/tmp/group/Stickers")
    }
}
