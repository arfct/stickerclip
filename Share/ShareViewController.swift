import SwiftUI
import UIKit

/// Hosts the share extension's SwiftUI root. P4 replaces the placeholder with
/// the importer; the shape — one hosting controller, dismissed through the
/// extension context — stays.
final class ShareViewController: UIViewController {
    override func loadView() {
        let host = UIHostingController(rootView: ShareRootView(done: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }))
        addChild(host)
        view = host.view
        host.didMove(toParent: self)
    }
}

struct ShareRootView: View {
    let done: () -> Void

    var body: some View {
        NavigationStack {
            StorageStatusView()
                .navigationTitle("Save to Stickerclip")
                .toolbar {
                    Button("Done", action: done)
                }
        }
    }
}
