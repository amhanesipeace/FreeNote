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
    /// Number of pages (optional so older single-page notes still decode).
    var pageCount: Int?

    init(id: UUID = UUID(), title: String = "Untitled",
         createdAt: Date = .now, modifiedAt: Date = .now,
         template: PageTemplate? = .lined, folder: String? = nil,
         pageCount: Int? = 1) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.template = template
        self.folder = folder
        self.pageCount = pageCount
    }

    /// The effective paper style (defaults to lined).
    var pageTemplate: PageTemplate { template ?? .lined }

    /// Number of pages (at least 1).
    var pages: Int { max(1, pageCount ?? 1) }

    /// Per-page file suffix: page 0 keeps the legacy name for backward
    /// compatibility; later pages get "_p1", "_p2", …
    func pageSuffix(_ page: Int) -> String { page == 0 ? "" : "_p\(page)" }

    /// Filename for a page's drawing bytes in the documents directory.
    func drawingFileName(page: Int = 0) -> String {
        "\(id.uuidString)\(pageSuffix(page)).drawing"
    }
}
