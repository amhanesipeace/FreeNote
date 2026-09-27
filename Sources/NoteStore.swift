import Foundation
import Combine

/// Owns the list of notes and their persistence.
///
/// - The list metadata (titles, dates) is saved as one small JSON file.
/// - Each note's drawing bytes are saved in their own file, loaded on demand.
///
/// Everything lives in the app's Documents directory — no cloud, no accounts,
/// no network. 100% local and free.
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let indexURL: URL
    private let docs: URL

    init() {
        docs = FileManager.default.urls(for: .documentDirectory,
                                        in: .userDomainMask)[0]
        indexURL = docs.appendingPathComponent("notes_index.json")
        load()
    }

    // MARK: - List operations

    /// Create a new empty note and return it (so the caller can open it).
    @discardableResult
    func addNote(title: String = "Untitled") -> Note {
        let note = Note(title: title)
        notes.insert(note, at: 0)      // newest first
        saveIndex()
        return note
    }

    func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            try? FileManager.default.removeItem(at: drawingURL(for: note))
            try? FileManager.default.removeItem(at: stickersURL(for: note))
        }
        notes.remove(atOffsets: offsets)
        saveIndex()
    }

    func rename(_ note: Note, to title: String) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].title = title.isEmpty ? "Untitled" : title
        notes[i].modifiedAt = .now
        saveIndex()
    }

    func setTemplate(_ template: PageTemplate, for note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].template = template
        notes[i].modifiedAt = .now
        saveIndex()
    }

    // MARK: - Drawing persistence

    func drawingURL(for note: Note) -> URL {
        docs.appendingPathComponent(note.drawingFileName)
    }

    /// Load a note's drawing bytes (nil if it has none yet).
    func loadDrawingData(for note: Note) -> Data? {
        try? Data(contentsOf: drawingURL(for: note))
    }

    /// Save drawing bytes for a note and bump its modified date.
    func saveDrawingData(_ data: Data, for note: Note) {
        try? data.write(to: drawingURL(for: note), options: .atomic)
        if let i = notes.firstIndex(where: { $0.id == note.id }) {
            notes[i].modifiedAt = .now
            // keep newest-modified at the top
            notes.sort { $0.modifiedAt > $1.modifiedAt }
            saveIndex()
        }
    }

    // MARK: - Sticker persistence

    private func stickersURL(for note: Note) -> URL {
        docs.appendingPathComponent("\(note.id.uuidString).stickers.json")
    }

    func loadStickers(for note: Note) -> [StickerItem] {
        guard let data = try? Data(contentsOf: stickersURL(for: note)),
              let items = try? JSONDecoder().decode([StickerItem].self, from: data)
        else { return [] }
        return items
    }

    func saveStickers(_ stickers: [StickerItem], for note: Note) {
        guard let data = try? JSONEncoder().encode(stickers) else { return }
        try? data.write(to: stickersURL(for: note), options: .atomic)
        if let i = notes.firstIndex(where: { $0.id == note.id }) {
            notes[i].modifiedAt = .now
            saveIndex()
        }
    }

    // MARK: - Index persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data)
        else { return }
        notes = decoded.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
