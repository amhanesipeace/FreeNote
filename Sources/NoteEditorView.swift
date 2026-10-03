import SwiftUI
import PencilKit
import PhotosUI

/// The writing surface for one note: hosts the markup canvas and auto-saves.
struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    let note: Note

    @State private var drawing = PKDrawing()
    @State private var loaded = false
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var template: PageTemplate = .lined
    @State private var stickers: [StickerItem] = []
    @State private var textBoxes: [TextBoxItem] = []
    @State private var showingStickerPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var currentPage = 0
    @State private var pageCount = 1

    var body: some View {
        CanvasView(drawing: $drawing, template: template,
                   stickers: $stickers, textBoxes: $textBoxes,
                   onChange: scheduleSave, onStickersChange: saveStickers,
                   onTextBoxesChange: saveTextBoxes)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { goToPage(currentPage - 1) } label: {
                        Image(systemName: "chevron.left")
                    }.disabled(currentPage == 0)
                    Text("\(currentPage + 1) / \(pageCount)")
                        .font(.subheadline).monospacedDigit()
                    Button { goToPage(currentPage + 1) } label: {
                        Image(systemName: "chevron.right")
                    }.disabled(currentPage >= pageCount - 1)
                    Button(action: addPage) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        exportAndShare()
                    } label: { Label("Share", systemImage: "square.and.arrow.up") }

                    Button {
                        addTextBox()
                    } label: { Label("Text", systemImage: "textformat") }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Photo", systemImage: "photo")
                    }

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
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await importPhoto(newItem); photoItem = nil }
            }
            .onAppear(perform: loadDrawing)
            .onDisappear(perform: saveNow)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let aspect = image.size.width > 0 ? image.size.height / image.size.width : 1
        let id = UUID()
        let file = store.saveStickerImage(data, id: id)
        let sticker = StickerItem(id: id, imageFile: file, aspect: aspect,
                                  x: 500, y: 500, size: 260)
        stickers.append(sticker)
        saveStickers(stickers)
    }

    private func addSticker(_ symbol: String, _ colorHex: String) {
        // Place near the top of the canvas where it's visible on open.
        let item = StickerItem(symbol: symbol, colorHex: colorHex, x: 500, y: 400)
        stickers.append(item)
        saveStickers(stickers)
    }

    private func saveStickers(_ items: [StickerItem]) {
        store.saveStickers(items, for: note, page: currentPage)
    }

    private func saveTextBoxes(_ items: [TextBoxItem]) {
        store.saveTextBoxes(items, for: note, page: currentPage)
    }

    // MARK: - Pages

    private func addPage() {
        saveNow()
        pageCount = store.addPage(to: note)
        goToPage(pageCount - 1, save: false)   // jump to the new blank page
    }

    /// Switch pages: persist the current page, then load the target page.
    private func goToPage(_ page: Int, save: Bool = true) {
        guard page >= 0, page < pageCount else { return }
        if save { saveNow() }
        currentPage = page
        loadPage()
    }

    /// Load the current page's content into the view state.
    private func loadPage() {
        stickers = store.loadStickers(for: note, page: currentPage)
        textBoxes = store.loadTextBoxes(for: note, page: currentPage)
        if let data = store.loadDrawingData(for: note, page: currentPage),
           let existing = try? PKDrawing(data: data) {
            drawing = existing
        } else {
            drawing = PKDrawing()
        }
    }

    private func addTextBox() {
        let box = TextBoxItem(text: "Tap to edit", x: 500, y: 420)
        textBoxes.append(box)
        saveTextBoxes(textBoxes)
    }

    /// Render the note to PDF (all pages) + PNG (current page) and present the
    /// iOS share sheet.
    private func exportAndShare() {
        saveNow()
        let title = note.title.isEmpty ? "Note" : note.title
        let dir = FileManager.default.temporaryDirectory
        var urls: [URL] = []

        // Gather every page's content from disk; use the just-saved in-memory
        // content for the current page so unsaved edits are included.
        var pages: [NoteRenderer.PageContent] = []
        for p in 0..<pageCount {
            let d: PKDrawing
            let st: [StickerItem]
            let tb: [TextBoxItem]
            if p == currentPage {
                d = drawing; st = stickers; tb = textBoxes
            } else {
                d = (try? PKDrawing(data: store.loadDrawingData(for: note, page: p)
                                    ?? Data())) ?? PKDrawing()
                st = store.loadStickers(for: note, page: p)
                tb = store.loadTextBoxes(for: note, page: p)
            }
            pages.append(.init(template: template, drawing: d, stickers: st, textBoxes: tb))
        }

        let pdf = NoteRenderer.pdf(pages: pages)
        let pdfURL = dir.appendingPathComponent("\(title).pdf")
        if (try? pdf.write(to: pdfURL)) != nil { urls.append(pdfURL) }

        if let png = NoteRenderer.image(template: template, drawing: drawing,
                stickers: stickers, textBoxes: textBoxes, outputWidth: 2000).pngData() {
            let pngURL = dir.appendingPathComponent("\(title).png")
            if (try? png.write(to: pngURL)) != nil { urls.append(pngURL) }
        }
        guard !urls.isEmpty,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first?
                .keyWindow?.rootViewController else { return }

        let av = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        av.popoverPresentationController?.sourceView = root.view
        av.popoverPresentationController?.sourceRect =
            CGRect(x: root.view.bounds.midX, y: 60, width: 1, height: 1)
        root.present(av, animated: true)
    }

    private func loadDrawing() {
        guard !loaded else { return }
        template = note.pageTemplate
        pageCount = note.pages
        currentPage = 0
        loadPage()
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
        store.saveDrawingData(drawing.dataRepresentation(), for: note, page: currentPage)
    }
}
