import StickerKit
import SwiftUI

/// The sticker you just added, before it joins the library: a real, draggable
/// sticker with the controls that shape it.
///
/// Laid out as the app always has been — the clip outline with the sticker
/// sitting inside it, a hint above, and a column of controls down the right.
/// The measurements come from the original storyboard: a 160pt outline, a
/// 136pt sticker, 44pt controls.
///
/// The preview is supplied by the surface. Messages passes an `MSStickerView`
/// so the sticker can be peeled into the conversation straight from here,
/// which is the point of editing in place rather than in a sheet.
///
/// Nothing here has a Save button. The draft is committed when the surface
/// goes away, so the sticker is kept whether or not the user thinks to
/// confirm it. Discard is the deliberate act.
struct StickerEditorView<Preview: View>: View {
    @Environment(LibraryModel.self) private var library
    let draft: DraftSticker
    @ViewBuilder let preview: (DraftSticker) -> Preview

    private let outline: CGFloat = 160
    private let sticker: CGFloat = 136
    private let control: CGFloat = 44

    private var sizeIndex: Int {
        StickerSize.all.firstIndex(of: draft.options.size) ?? StickerSize.all.firstIndex(of: StickerSize.default)!
    }

    var body: some View {
        VStack(spacing: 4) {
            Label("Drag sticker to attach it", systemImage: "arrow.up")
                .labelStyle(.titleAndTrailingIcon)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(height: 34)

            HStack(spacing: 0) {
                discardButton
                    .frame(width: control)

                ZStack {
                    Image("Clip")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .opacity(0.55)
                        .frame(width: outline, height: outline)
                    preview(draft)
                        .frame(width: sticker, height: sticker)
                }
                .frame(maxWidth: .infinity)

                controls
                    .frame(width: control)
            }
        }
        .padding(.bottom, 8)
    }

    /// Down the right of the sticker, as in the original: outline, bigger,
    /// smaller. An animated GIF is passed through whole, so there is nothing
    /// for them to act on — resizing or outlining it would flatten it to a
    /// single frame.
    @ViewBuilder
    private var controls: some View {
        if draft.isPassthrough {
            Image(systemName: "play.circle")
                .imageScale(.large)
                .foregroundStyle(.tertiary)
                .frame(width: control, height: control)
                .accessibilityLabel("Animated, kept as-is")
        } else {
            VStack(spacing: 0) {
                control("Outline", symbol: draft.options.hasBorder ? "circle.circle.fill" : "circle.circle") {
                    update(\.hasBorder, to: !draft.options.hasBorder)
                }
                control("Bigger", symbol: "plus.circle") { step(by: -1) }
                    .disabled(sizeIndex <= 0)
                control("Smaller", symbol: "minus.circle") { step(by: 1) }
                    .disabled(sizeIndex >= StickerSize.all.count - 1)
            }
        }
    }

    private var discardButton: some View {
        control("Discard", symbol: "xmark.circle") {
            Task { await library.discardDraft() }
        }
    }

    private func control(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(.large)
                .frame(width: control, height: control)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(title)
    }

    private func update<T>(_ key: WritableKeyPath<StickerRenderer.Options, T>, to value: T) {
        var options = draft.options
        options[keyPath: key] = value
        Task { await library.updateDraft(options) }
    }

    /// `StickerSize.all` runs largest to smallest, so a positive step shrinks.
    private func step(by delta: Int) {
        let index = min(max(sizeIndex + delta, 0), StickerSize.all.count - 1)
        update(\.size, to: StickerSize.all[index])
    }
}

/// The original's hint put its arrow after the text.
struct TitleAndTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

extension LabelStyle where Self == TitleAndTrailingIconLabelStyle {
    static var titleAndTrailingIcon: TitleAndTrailingIconLabelStyle { .init() }
}
