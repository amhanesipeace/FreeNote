import SwiftUI
import PencilKit

/// The home screen: a list of notes with create / open / rename / delete.
struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @State private var renaming: Note?
    @State private var renameText = ""
    @State private var filing: Note?
    @State private var folderText = ""
    @State private var searchText = ""
    @State private var selectedFolder: String?      // nil = All
    @State private var path: [Note] = []

    /// Notes after applying the folder filter and title search.
    private var filteredNotes: [Note] {
        store.notes.filter { note in
            let folderOK = selectedFolder == nil || note.folder == selectedFolder
            let searchOK = searchText.isEmpty ||
                note.title.localizedCaseInsensitiveContains(searchText)
            return folderOK && searchOK
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.notes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(selectedFolder ?? "FreeNote")
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                if !store.folders.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { folderMenu }
                }
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
            .alert("Move to folder", isPresented: filingBinding) {
                TextField("Folder name (blank = none)", text: $folderText)
                Button("Cancel", role: .cancel) { filing = nil }
                Button("Save") {
                    if let note = filing { store.setFolder(folderText, for: note) }
                    filing = nil
                }
            }
        }
    }

    private var folderMenu: some View {
        Menu {
            Picker("Folder", selection: $selectedFolder) {
                Label("All Notes", systemImage: "tray.full").tag(String?.none)
                ForEach(store.folders, id: \.self) { folder in
                    Label(folder, systemImage: "folder").tag(String?.some(folder))
                }
            }
        } label: {
            Label("Folders", systemImage: "folder")
        }
    }

    private var list: some View {
        List {
            ForEach(filteredNotes) { note in
                NavigationLink(value: note) {
                    HStack(spacing: 12) {
                        NoteThumbnail(note: note)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title).font(.headline)
                            HStack(spacing: 6) {
                                if let folder = note.folder {
                                    Label(folder, systemImage: "folder")
                                        .font(.caption2).foregroundStyle(.tint)
                                }
                                Text(note.modifiedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        renaming = note
                        renameText = note.title
                    } label: { Label("Rename", systemImage: "pencil") }
                    .tint(.blue)
                    Button {
                        filing = note
                        folderText = note.folder ?? ""
                    } label: { Label("Folder", systemImage: "folder") }
                    .tint(.orange)
                }
            }
            .onDelete(perform: deleteFiltered)
        }
        .overlay {
            if filteredNotes.isEmpty {
                ContentUnavailableView.search
            }
        }
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
    }

    /// Map deletions from the filtered list back to the store's indices.
    private func deleteFiltered(at offsets: IndexSet) {
        let ids = offsets.map { filteredNotes[$0].id }
        let storeIndices = IndexSet(store.notes.indices.filter {
            ids.contains(store.notes[$0].id) })
        store.deleteNotes(at: storeIndices)
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
        // New notes inherit the currently-selected folder.
        let note = store.addNote()
        if let folder = selectedFolder { store.setFolder(folder, for: note) }
    }

    private var filingBinding: Binding<Bool> {
        Binding(get: { filing != nil }, set: { if !$0 { filing = nil } })
    }

    /// Test hook: `-UITEST_OPEN_CANVAS` opens straight into a note so the canvas
    /// can be captured in an automated screenshot. No effect in normal use.
    private func handleUITestLaunch() {
        // Seed a few foldered notes and stay on the list (for folder/search shots).
        if ProcessInfo.processInfo.arguments.contains("UITEST_SEED_LIST"),
           store.notes.isEmpty {
            let specs = [("Math lecture", "School"), ("Grocery list", "Personal"),
                         ("Sprint planning", "Work"), ("Book ideas", "Personal")]
            for (title, folder) in specs {
                store.setFolder(folder, for: store.addNote(title: title))
            }
        }

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
        // Render the note to a PNG in Documents so tests can verify the renderer.
        if ProcessInfo.processInfo.arguments.contains("UITEST_EXPORT") {
            let n = store.notes.first(where: { $0.id == note.id }) ?? note
            let drawing = (try? PKDrawing(data: store.loadDrawingData(for: n) ?? Data()))
                ?? PKDrawing()
            let png = NoteRenderer.image(template: n.pageTemplate, drawing: drawing,
                stickers: store.loadStickers(for: n),
                textBoxes: store.loadTextBoxes(for: n), outputWidth: 1400).pngData()
            if let png { try? png.write(to: AppPaths.documents
                .appendingPathComponent("export_preview.png")) }
        }
        path = [store.notes.first(where: { $0.id == note.id }) ?? note]
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
