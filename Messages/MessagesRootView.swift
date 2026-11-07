import StickerKit
import SwiftUI

/// Root of the Messages extension: the library, with the ways to add a
/// sticker anchored along the bottom.
///
/// The bar is built rather than given to `.toolbar(placement: .bottomBar)`,
/// which does not render inside the extension's compact presentation. There
/// is no `NavigationStack` either — nothing here navigates, and the space a
/// bar would take is most of what compact has.
///
/// The extension stays compact, so deleting happens through a sticker's
/// context menu rather than a selection mode needing a second bar's room.
struct MessagesRootView: View {
    @Environment(LibraryModel.self) private var library

    var body: some View {
        grid
            .overlay(alignment: .bottom) { addBar }
            // Text buttons in the label colour rather than accent blue.
            .tint(.primary)
            .task { await library.load() }
            .alert("Couldn't make a sticker", isPresented: Binding(
                get: { library.lastError != nil }, set: { if !$0 { library.clearError() } }
            )) {
                Button("OK") { library.clearError() }
            } message: {
                Text(library.lastError ?? "")
            }
    }

    /// Glass on each button, not on a container around them, and each its
    /// own target rather than one grouped capsule.
    private var addBar: some View {
        HStack(spacing: 10) {
            PasteStickerButton()
            Spacer(minLength: 12)
            AddStickerMenu()
        }
        .padding(.horizontal, GlassMetrics.margin)
        .padding(.bottom, GlassMetrics.margin)
        // safeAreaInset would hold the bar above the home-indicator inset,
        // which is most of the gap under it. This reaches into that region so
        // the buttons sit in the corners.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private var grid: some View {
        if library.stickers.isEmpty, library.draft == nil, library.isReady, !library.isLoading {
            ContentUnavailableView {
                Label("No stickers yet", systemImage: "square.on.square.dashed")
            } description: {
                Text("Paste an image from the clipboard, or add one from Files or Photos.")
            }
        } else {
            ScrollView {
                if let draft = library.draft {
                    StickerEditorView(draft: draft) { draft in
                        MessagesStickerView(draft: draft)
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(library.stickers) { sticker in
                        // The system view, so peel-to-drag and tap-to-insert
                        // are Messages' own.
                        MessagesStickerView(sticker: sticker)
                            .frame(height: 92)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await library.remove([sticker]) }
                                }
                            }
                    }
                }
                .padding(16)
                // Room for the bar the grid now scrolls beneath.
                .padding(.bottom, GlassMetrics.button + GlassMetrics.margin * 2)
            }
            .overlay {
                if library.isImporting { ProgressView().controlSize(.large) }
            }
            .animation(.default, value: library.draft?.url)
        }
    }
}
