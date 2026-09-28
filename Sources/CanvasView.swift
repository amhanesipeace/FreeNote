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
    /// Paper style drawn behind the ink.
    var template: PageTemplate
    /// Stickers placed on the page.
    @Binding var stickers: [StickerItem]
    /// Text boxes placed on the page.
    @Binding var textBoxes: [TextBoxItem]
    /// Called whenever the drawing changes, so the editor can auto-save.
    var onChange: (PKDrawing) -> Void
    /// Called whenever stickers change (move/resize/add/delete), to persist.
    var onStickersChange: ([StickerItem]) -> Void
    /// Called whenever text boxes change, to persist.
    var onTextBoxesChange: ([TextBoxItem]) -> Void

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
        canvas.backgroundColor = .clear   // let the paper view show through

        // Expansive, zoomable canvas.
        canvas.minimumZoomScale = 0.5
        canvas.maximumZoomScale = 4.0
        canvas.contentSize = Self.canvasSize

        // Paper view: a content subview (so it scrolls with the ink) filling the
        // whole canvas, filled with the template's tiled pattern. Kept at the
        // back so ink always draws on top.
        let paper = UIView(frame: CGRect(origin: .zero, size: Self.canvasSize))
        paper.backgroundColor = template.patternColor()
        canvas.addSubview(paper)
        canvas.sendSubviewToBack(paper)
        context.coordinator.paperView = paper
        context.coordinator.canvas = canvas
        context.coordinator.syncStickers(stickers)
        context.coordinator.syncTextBoxes(textBoxes)

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
        // Update paper style if it changed, and keep it at the back.
        if let paper = context.coordinator.paperView {
            paper.backgroundColor = template.patternColor()
            canvas.sendSubviewToBack(paper)
        }
        context.coordinator.syncStickers(stickers)
        context.coordinator.syncTextBoxes(textBoxes)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: CanvasView
        let toolPicker = PKToolPicker()
        weak var paperView: UIView?
        weak var canvas: PKCanvasView?
        private var stickerViews: [UUID: StickerView] = [:]
        private var textBoxViews: [UUID: TextBoxView] = [:]

        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.onChange(canvasView.drawing)
        }

        /// Reconcile the sticker subviews with the model array: add new ones,
        /// update geometry of existing ones, remove deleted ones.
        func syncStickers(_ items: [StickerItem]) {
            guard let canvas else { return }
            let ids = Set(items.map(\.id))

            // Remove stickers no longer in the model.
            for (id, view) in stickerViews where !ids.contains(id) {
                view.removeFromSuperview()
                stickerViews[id] = nil
            }

            for item in items {
                if let view = stickerViews[item.id] {
                    // Update only if not currently being dragged (avoid fighting).
                    if !view.isInteracting { view.apply(item) }
                } else {
                    let view = StickerView(item: item)
                    view.onChange = { [weak self] v in self?.stickerChanged(v) }
                    view.onTap = { [weak self] v in self?.stickerTapped(v) }
                    canvas.addSubview(view)   // on top of the ink
                    stickerViews[item.id] = view
                }
            }
        }

        private func stickerChanged(_ view: StickerView) {
            guard let i = parent.stickers.firstIndex(where: { $0.id == view.stickerID })
            else { return }
            parent.stickers[i] = view.asItem()
            parent.onStickersChange(parent.stickers)
        }

        /// Reconcile text-box subviews with the model array.
        func syncTextBoxes(_ items: [TextBoxItem]) {
            guard let canvas else { return }
            let ids = Set(items.map(\.id))
            for (id, view) in textBoxViews where !ids.contains(id) {
                view.removeFromSuperview()
                textBoxViews[id] = nil
            }
            for item in items {
                if let view = textBoxViews[item.id] {
                    if !view.isInteracting { view.apply(item) }
                } else {
                    let view = TextBoxView(item: item)
                    view.onChange = { [weak self] v in self?.textBoxChanged(v) }
                    canvas.addSubview(view)
                    textBoxViews[item.id] = view
                }
            }
        }

        private func textBoxChanged(_ view: TextBoxView) {
            guard let i = parent.textBoxes.firstIndex(where: { $0.id == view.boxID })
            else { return }
            parent.textBoxes[i] = view.asItem()
            parent.onTextBoxesChange(parent.textBoxes)
        }

        private func stickerTapped(_ view: StickerView) {
            // Simple delete affordance: confirm, then remove.
            guard let vc = view.window?.rootViewController else { return }
            let sheet = UIAlertController(title: "Sticker", message: nil,
                                          preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Delete sticker", style: .destructive) {
                [weak self] _ in
                guard let self else { return }
                self.parent.stickers.removeAll { $0.id == view.stickerID }
                self.parent.onStickersChange(self.parent.stickers)
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = view.bounds
            vc.present(sheet, animated: true)
        }
    }
}
