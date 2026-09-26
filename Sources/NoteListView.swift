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
        path = [store.notes.first(where: { $0.id == note.id }) ?? note]
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
