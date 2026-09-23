import Foundation

/// One note = some metadata + a PencilKit drawing stored as raw Data.
///
/// We keep the heavy drawing bytes on disk (one file per note) and only load
/// them when a note is opened, so the notes list stays fast even with many
/// large notes.
struct Note: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), title: String = "Untitled",
         createdAt: Date = .now, modifiedAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Filename for this note's drawing bytes inside the documents directory.
    var drawingFileName: String { "\(id.uuidString).drawing" }
}
