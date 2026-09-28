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
    /// Paper style. Optional so notes saved before templates existed still
    /// decode; `nil` is treated as `.lined` in the UI.
    var template: PageTemplate?
    /// Optional folder name (nil = not filed).
    var folder: String?

    init(id: UUID = UUID(), title: String = "Untitled",
         createdAt: Date = .now, modifiedAt: Date = .now,
         template: PageTemplate? = .lined, folder: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.template = template
        self.folder = folder
    }

    /// The effective paper style (defaults to lined).
    var pageTemplate: PageTemplate { template ?? .lined }

    /// Filename for this note's drawing bytes inside the documents directory.
    var drawingFileName: String { "\(id.uuidString).drawing" }
}
