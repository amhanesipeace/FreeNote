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

    /// `directory` defaults to the app's Documents folder; tests inject a temp
    /// directory so they never touch real data.
    init(directory: URL? = nil) {
        docs = directory ?? FileManager.default.urls(for: .documentDirectory,
                                                     in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: docs,
            withIntermediateDirectories: true)
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
            // Remove any imported photo files this note's stickers referenced.
            for sticker in loadStickers(for: note) {
                if let file = sticker.imageFile {
                    try? FileManager.default.removeItem(
                        at: docs.appendingPathComponent(file))
                }
            }
            try? FileManager.default.removeItem(at: drawingURL(for: note))
            try? FileManager.default.removeItem(at: stickersURL(for: note))
            try? FileManager.default.removeItem(at: textBoxesURL(for: note))
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

    func setFolder(_ folder: String?, for note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        let trimmed = folder?.trimmingCharacters(in: .whitespaces)
        notes[i].folder = (trimmed?.isEmpty ?? true) ? nil : trimmed
        saveIndex()
    }

    /// Distinct folder names currently in use, sorted.
    var folders: [String] {
        Set(notes.compactMap(\.folder)).sorted()
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

    /// Save an imported photo's bytes and return the filename to store on the
    /// sticker. Files live in Documents alongside everything else.
    func saveStickerImage(_ data: Data, id: UUID = UUID()) -> String {
        let filename = "sticker_\(id.uuidString).png"
        try? data.write(to: docs.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    // MARK: - Text-box persistence

    private func textBoxesURL(for note: Note) -> URL {
        docs.appendingPathComponent("\(note.id.uuidString).textboxes.json")
    }

    func loadTextBoxes(for note: Note) -> [TextBoxItem] {
        guard let data = try? Data(contentsOf: textBoxesURL(for: note)),
              let items = try? JSONDecoder().decode([TextBoxItem].self, from: data)
        else { return [] }
        return items
    }

    func saveTextBoxes(_ boxes: [TextBoxItem], for note: Note) {
        guard let data = try? JSONEncoder().encode(boxes) else { return }
        try? data.write(to: textBoxesURL(for: note), options: .atomic)
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
