import SwiftUI

/// The home screen: a list of notes with create / open / rename / delete.
struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @State private var renaming: Note?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
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

    private var renameBinding: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
