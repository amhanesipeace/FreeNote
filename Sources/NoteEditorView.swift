import SwiftUI
import PencilKit

/// The writing surface for one note: hosts the markup canvas and auto-saves.
struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    let note: Note

    @State private var drawing = PKDrawing()
    @State private var loaded = false
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var template: PageTemplate = .lined

    var body: some View {
        CanvasView(drawing: $drawing, template: template, onChange: scheduleSave)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Paper", selection: $template) {
                            ForEach(PageTemplate.allCases) { t in
                                Label(t.label, systemImage: t.systemImage).tag(t)
                            }
                        }
                    } label: {
                        Label("Paper", systemImage: "square.grid.2x2")
                    }
                }
            }
            .onChange(of: template) { _, newValue in
                store.setTemplate(newValue, for: note)
            }
            .onAppear(perform: loadDrawing)
            .onDisappear(perform: saveNow)
    }

    private func loadDrawing() {
        guard !loaded else { return }
        template = note.pageTemplate
        if let data = store.loadDrawingData(for: note),
           let existing = try? PKDrawing(data: data) {
            drawing = existing
        }
        loaded = true
    }

    /// Debounced auto-save: coalesce rapid stroke changes into one write ~1s
    /// after the user pauses, so we're not hitting disk on every pen movement.
    private func scheduleSave(_ newDrawing: PKDrawing) {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { save(newDrawing) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func saveNow() {
        saveWorkItem?.cancel()
        save(drawing)
    }

    private func save(_ drawing: PKDrawing) {
        store.saveDrawingData(drawing.dataRepresentation(), for: note)
    }
}
