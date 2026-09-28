import SwiftUI
import PencilKit

/// Cache of rendered thumbnails, keyed by note id + modified time so a note's
/// thumbnail is re-rendered only when it actually changes.
enum ThumbCache {
    static let cache = NSCache<NSString, UIImage>()
}

/// A small live preview of a note's page, shown in the notes list.
struct NoteThumbnail: View {
    @EnvironmentObject var store: NoteStore
    let note: Note
    @State private var image: UIImage?

    private let w: CGFloat = 54
    private let h: CGFloat = 70

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "doc.text").foregroundStyle(.secondary)
            }
        }
        .frame(width: w, height: h)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))
        .task(id: note.modifiedAt) { render() }
    }

    private func render() {
        let key = "\(note.id.uuidString)-\(note.modifiedAt.timeIntervalSince1970)" as NSString
        if let cached = ThumbCache.cache.object(forKey: key) { image = cached; return }
        let drawing = (try? PKDrawing(data: store.loadDrawingData(for: note) ?? Data()))
            ?? PKDrawing()
        let img = NoteRenderer.image(template: note.pageTemplate, drawing: drawing,
                                     stickers: store.loadStickers(for: note),
                                     textBoxes: store.loadTextBoxes(for: note),
                                     outputWidth: 160)
        ThumbCache.cache.setObject(img, forKey: key)
        image = img
    }
}
