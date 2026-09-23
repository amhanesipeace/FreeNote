import SwiftUI

/// App entry point. A single shared NoteStore holds all notes and persists
/// them to disk; the UI observes it so the notes list stays in sync.
@main
struct FreeNoteApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            NoteListView()
                .environmentObject(store)
        }
    }
}
