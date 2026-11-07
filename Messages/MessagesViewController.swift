import Messages
import SwiftUI
import UIKit

/// The only UIKit in the project: Messages requires an
/// `MSMessagesAppViewController`, so this one hosts the SwiftUI root and
/// relays presentation changes. It is installed in `loadView`, so there is
/// never a moment where a placeholder view is on screen.
final class MessagesViewController: MSMessagesAppViewController {
    private let library = LibraryModel()
    private let host = MessagesHost()

    override func loadView() {
        host.requestPresentation = { [weak self] style in self?.requestPresentationStyle(style) }

        let root = MessagesRootView()
            .environment(library)
            .environment(host)
        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear

        view = UIView()
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)

        // The system filters a paste by the types its target declares.
        let accepting = UIPasteConfiguration(forAccepting: UIImage.self)
        accepting.addTypeIdentifiers(forAccepting: NSURL.self)
        accepting.addTypeIdentifiers(forAccepting: NSString.self)
        pasteConfiguration = accepting
    }

    override func willBecomeActive(with conversation: MSConversation) {
        host.didTransition(to: presentationStyle)
    }

    /// Where a draft is kept. The editor has no Save button, so leaving the
    /// extension is what saves — the sticker survives whether or not the user
    /// thought to confirm it.
    override func didResignActive(with conversation: MSConversation) {
        Task { await library.commitDraft() }
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        host.didTransition(to: presentationStyle)
    }

    // Polled by the system every couple of seconds while a paste control is
    // on screen, and on iOS 26 often with an empty array. It must answer and
    // do nothing else; the previous app rebuilt its UI here and lost its paste
    // control to the polling.
    override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
        true
    }

    /// Reached by a system paste aimed at the controller itself (a hardware
    /// keyboard's ⌘V, for instance); the on-screen control has its own path.
    override func paste(itemProviders: [NSItemProvider]) {
        Task { await library.add(itemProviders) }
    }
}
