import SwiftUI

enum GlassMetrics {
    /// The standard size of a Liquid Glass control, so the wrapped UIKit
    /// paste control matches the SwiftUI buttons beside it.
    static let button: CGFloat = 48

    /// Inset from the container's edges. The same on the sides and the
    /// bottom, so the controls sit evenly in the corners.
    static let margin: CGFloat = 32
}

/// Liquid Glass arrived in iOS 26 and the deployment target is iOS 18, so
/// every use of it is guarded. On 18 the controls keep their plain
/// appearance; nothing is conditioned on the look beyond the look itself.
extension View {
    /// Glass on this control alone, rather than inheriting a container's.
    @ViewBuilder
    func individualGlass() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass).buttonBorderShape(.circle)
        } else {
            self
        }
    }

    /// For controls that are not buttons — a `UIViewRepresentable`, say —
    /// where `buttonStyle` has nothing to apply to.
    @ViewBuilder
    func individualGlassEffect(in shape: some Shape = .capsule) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            self
        }
    }
}

extension ToolbarContent {
    /// Drops the toolbar's shared background so each item carries its own.
    @ToolbarContentBuilder
    func withoutSharedBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
