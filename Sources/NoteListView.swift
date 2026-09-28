import SwiftUI

/// The home screen: a list of notes with create / open / rename / delete.
struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @State private var renaming: Note?
    @State private var renameText = ""
    @State private var path: [Note] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.notes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("FreeNote")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: newNote) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                }
            }
            .onAppear(perform: handleUITestLaunch)
            .alert("Rename note", isPresented: renameBinding) {
                TextField("Title", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let note = renaming { store.rename(note, to: renameText) }
                    renaming = nil
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.notes) { note in
                NavigationLink(value: note) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).font(.headline)
                        Text(note.modifiedAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        renaming = note
                        renameText = note.title
                    } label: { Label("Rename", systemImage: "pencil") }
                    .tint(.blue)
                }
            }
            .onDelete(perform: store.deleteNotes)
        }
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No notes yet", systemImage: "book.closed")
        } description: {
            Text("Tap the pencil to start your first note.")
        } actions: {
            Button("New Note", action: newNote).buttonStyle(.borderedProminent)
        }
    }

    private func newNote() {
        store.addNote()
    }

    /// Test hook: `-UITEST_OPEN_CANVAS` opens straight into a note so the canvas
    /// can be captured in an automated screenshot. No effect in normal use.
    private func handleUITestLaunch() {
        guard ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_CANVAS"),
              path.isEmpty else { return }
        let note = store.notes.first ?? store.addNote(title: "Sample")
        // Let a second arg pick the paper style for screenshots, e.g. "grid".
        if let tArg = ProcessInfo.processInfo.arguments.first(where: {
            PageTemplate(rawValue: $0) != nil }),
           let t = PageTemplate(rawValue: tArg) {
            store.setTemplate(t, for: note)
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_SEED_STICKERS") {
            var items = [
                StickerItem(symbol: "star.fill", colorHex: "#FFCC00", x: 320, y: 360, size: 150),
                StickerItem(symbol: "flame.fill", colorHex: "#FF9500", x: 640, y: 300, size: 130, rotation: 0.2),
                StickerItem(symbol: "heart.fill", colorHex: "#FF3B30", x: 480, y: 580, size: 140, rotation: -0.15),
            ]
            // Generate a sample "photo" (portrait aspect) to exercise the image path.
            let sz = CGSize(width: 300, height: 450)
            let img = UIGraphicsImageRenderer(size: sz).image { ctx in
                let cg = ctx.cgContext
                let colors = [UIColor.systemTeal.cgColor, UIColor.systemIndigo.cgColor]
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray, locations: [0, 1])!
                cg.drawLinearGradient(grad, start: .zero,
                                      end: CGPoint(x: sz.width, y: sz.height), options: [])
                UIColor.white.setFill()
                "🖼".draw(at: CGPoint(x: 110, y: 180),
                          withAttributes: [.font: UIFont.systemFont(ofSize: 80)])
            }
            if let data = img.pngData() {
                let id = UUID()
                let file = store.saveStickerImage(data, id: id)
                items.append(StickerItem(id: id, imageFile: file, aspect: 1.5,
                                         x: 900, y: 520, size: 240, rotation: 0.1))
            }
            store.saveStickers(items, for: note)
            store.saveTextBoxes([
                TextBoxItem(text: "Meeting notes ✏️", colorHex: "#5856D6",
                            fontSize: 44, x: 430, y: 200),
                TextBoxItem(text: "- ship v0.4\n- test text boxes", colorHex: "#1C1C1E",
                            fontSize: 30, x: 380, y: 760, rotation: -0.05),
            ], for: note)
        }
        path = [store.notes.first(where: { $0.id == note.id }) ?? note]
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
