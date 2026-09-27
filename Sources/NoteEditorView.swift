import SwiftUI
import PencilKit

/// The writing surface for one note: hosts the markup canvas and auto-saves.
struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    let note: Note

    @State private var drawing = PKDrawing()
    @State private var loaded = false
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var template: PageTemplate = .lined
    @State private var stickers: [StickerItem] = []
    @State private var showingStickerPicker = false

    var body: some View {
        CanvasView(drawing: $drawing, template: template, stickers: $stickers,
                   onChange: scheduleSave, onStickersChange: saveStickers)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingStickerPicker = true
                    } label: { Label("Sticker", systemImage: "face.smiling") }

                    Menu {
                        Picker("Paper", selection: $template) {
                            ForEach(PageTemplate.allCases) { t in
                                Label(t.label, systemImage: t.systemImage).tag(t)
                            }
                        }
                    } label: {
                        Label("Paper", systemImage: "square.grid.2x2")
                    }
                }
            }
            .sheet(isPresented: $showingStickerPicker) {
                StickerPicker { symbol, colorHex in
                    addSticker(symbol, colorHex)
                    showingStickerPicker = false
                }
            }
            .onChange(of: template) { _, newValue in
                store.setTemplate(newValue, for: note)
            }
            .onAppear(perform: loadDrawing)
            .onDisappear(perform: saveNow)
    }

    private func addSticker(_ symbol: String, _ colorHex: String) {
        // Place near the top of the canvas where it's visible on open.
        let item = StickerItem(symbol: symbol, colorHex: colorHex, x: 500, y: 400)
        stickers.append(item)
        saveStickers(stickers)
    }

    private func saveStickers(_ items: [StickerItem]) {
        store.saveStickers(items, for: note)
    }

    private func loadDrawing() {
        guard !loaded else { return }
        template = note.pageTemplate
        stickers = store.loadStickers(for: note)
        if let data = store.loadDrawingData(for: note),
           let existing = try? PKDrawing(data: data) {
            drawing = existing
        }
        loaded = true
    }

    /// Debounced auto-save: coalesce rapid stroke changes into one write ~1s
    /// after the user pauses, so we're not hitting disk on every pen movement.
    private func scheduleSave(_ newDrawing: PKDrawing) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { save(newDrawing) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func saveNow() {
        saveWorkItem?.cancel()
        save(drawing)
    }

    private func save(_ drawing: PKDrawing) {
        store.saveDrawingData(drawing.dataRepresentation(), for: note)
    }
}
