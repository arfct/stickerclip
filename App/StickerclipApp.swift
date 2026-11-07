import SwiftUI

@main
struct StickerclipApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StorageStatusView()
                    .navigationTitle("Stickerclip")
            }
        }
    }
}
