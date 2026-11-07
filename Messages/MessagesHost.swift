import Messages
import SwiftUI

/// What the SwiftUI side needs to know about, and ask of, the Messages
/// controller: the current presentation style, and a way to change it.
@MainActor @Observable
final class MessagesHost {
    private(set) var presentationStyle: MSMessagesAppPresentationStyle = .compact
    var requestPresentation: (MSMessagesAppPresentationStyle) -> Void = { _ in }

    var isExpanded: Bool { presentationStyle == .expanded }

    func didTransition(to style: MSMessagesAppPresentationStyle) {
        presentationStyle = style
    }

    func expand() { requestPresentation(.expanded) }
    func collapse() { requestPresentation(.compact) }
}
