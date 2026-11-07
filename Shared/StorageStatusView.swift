import SwiftUI
import StickerKit

/// P0 placeholder for every surface: shows where this process resolved the
/// library, which verifies the App Group and iCloud entitlements on a real
/// device before any sticker code exists.
struct StorageStatusView: View {
    @State private var location: LibraryLocation?

    var body: some View {
        List {
            if let location {
                LabeledContent("Storage", value: label(for: location))
                LabeledContent("Synced", value: location.isSynced ? "iCloud" : "This device")
                Text(location.stickersDirectory.path)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else {
                ProgressView("Resolving storage…")
            }
        }
        .task { location = await LibraryLocation.resolve() }
    }

    private func label(for location: LibraryLocation) -> String {
        switch location {
        case .iCloud: "iCloud Drive"
        case .appGroup: "App Group"
        case .processLocal: "Process only"
        }
    }
}
