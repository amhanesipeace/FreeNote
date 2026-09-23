import SwiftUI
import PencilKit

/// SwiftUI wrapper around PencilKit's PKCanvasView — this is what gives us
/// professional markup for free: pen / pencil / marker / eraser, Apple Pencil
/// pressure & tilt, color and width, lasso selection, and undo.
///
/// PKCanvasView is itself a UIScrollView, so we give it a large content size
/// and enable zoom/pan — a big, expansive canvas to write on. (True *infinite*
/// canvas is a later step; see the roadmap.)
struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    /// Called whenever the drawing changes, so the editor can auto-save.
    var onChange: (PKDrawing) -> Void

    /// A generous canvas size — feels large and scrollable on iPad.
    static let canvasSize = CGSize(width: 3000, height: 4000)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.alwaysBounceVertical = true
        canvas.alwaysBounceHorizontal = true
        // Allow drawing with finger too (not just Apple Pencil) so it works in
        // the Simulator and for people without a Pencil.
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .systemBackground

        // Expansive, zoomable canvas.
        canvas.minimumZoomScale = 0.5
        canvas.maximumZoomScale = 4.0
        canvas.contentSize = Self.canvasSize

        // Show Apple's floating tool picker and make the canvas active for it.
        let picker = context.coordinator.toolPicker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Only push external changes in (avoids clobbering active strokes).
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasView
        let toolPicker = PKToolPicker()

        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChange(canvasView.drawing)
        }
    }
}
