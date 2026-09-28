import PencilKit
import UIKit

/// Renders a whole note — paper + ink + stickers + photos + text — into a flat
/// image or PDF. Shared by note thumbnails (small) and export/share (large).
enum NoteRenderer {

    /// Bounding region (in canvas coordinates) that contains all content, with
    /// padding. Falls back to a portrait page when the note is empty.
    static func contentRegion(drawing: PKDrawing, stickers: [StickerItem],
                              textBoxes: [TextBoxItem]) -> CGRect {
        var rect: CGRect? = nil
        func add(_ r: CGRect) { rect = rect.map { $0.union(r) } ?? r }

        if !drawing.bounds.isNull && !drawing.bounds.isEmpty { add(drawing.bounds) }
        for s in stickers {
            let h = s.size * s.aspect
            add(CGRect(x: s.x - s.size / 2, y: s.y - h / 2, width: s.size, height: h))
        }
        for t in textBoxes {
            let h = textHeight(t)
            add(CGRect(x: t.x - t.width / 2, y: t.y - h / 2, width: t.width, height: h))
        }

        guard var region = rect else {
            return CGRect(x: 0, y: 0, width: 1200, height: 1600)  // empty note
        }
        region = region.insetBy(dx: -80, dy: -80)
        // keep within the canvas and enforce a sane minimum size
        region = region.intersection(CGRect(x: 0, y: 0, width: 3000, height: 4000))
        if region.width < 400 { region.size.width = 400 }
        if region.height < 400 { region.size.height = 400 }
        return region
    }

    private static func textHeight(_ t: TextBoxItem) -> CGFloat {
        let attr = NSAttributedString(string: t.text.isEmpty ? " " : t.text,
            attributes: [.font: UIFont.systemFont(ofSize: t.fontSize)])
        let bound = attr.boundingRect(
            with: CGSize(width: t.width - 16, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return max(44, ceil(bound.height) + 16)
    }

    /// Render to a UIImage whose width is `outputWidth` pixels (height keeps the
    /// region's aspect ratio).
    static func image(template: PageTemplate, drawing: PKDrawing,
                      stickers: [StickerItem], textBoxes: [TextBoxItem],
                      outputWidth: CGFloat = 1400) -> UIImage {
        let region = contentRegion(drawing: drawing, stickers: stickers,
                                   textBoxes: textBoxes)
        let scale = outputWidth / region.width
        let size = CGSize(width: outputWidth, height: region.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { rctx in
            let cg = rctx.cgContext

            // Paper: white, then tile the template pattern (scaled).
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            if template != .blank {
                let tile = template.patternImage()
                let tw = tile.size.width * scale, th = tile.size.height * scale
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        tile.draw(in: CGRect(x: x, y: y, width: tw, height: th))
                        x += tw
                    }
                    y += th
                }
            }

            // Ink.
            let ink = drawing.image(from: region, scale: scale)
            ink.draw(in: CGRect(origin: .zero, size: size))

            // Helper to map a canvas point into output space.
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: (p.x - region.minX) * scale, y: (p.y - region.minY) * scale)
            }

            // Stickers.
            for s in stickers {
                let w = s.size * scale, h = s.size * s.aspect * scale
                let img: UIImage?
                if let file = s.imageFile {
                    img = UIImage(contentsOfFile: AppPaths.documents
                        .appendingPathComponent(file).path)
                } else {
                    img = UIImage(systemName: s.symbol)?
                        .withTintColor(UIColor(hex: s.colorHex), renderingMode: .alwaysOriginal)
                }
                guard let image = img else { continue }
                cg.saveGState()
                let c = map(CGPoint(x: s.x, y: s.y))
                cg.translateBy(x: c.x, y: c.y)
                cg.rotate(by: s.rotation)
                image.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                cg.restoreGState()
            }

            // Text boxes.
            for t in textBoxes {
                let w = t.width * scale
                let h = textHeight(t) * scale
                let para = NSMutableParagraphStyle()
                let attr = NSAttributedString(string: t.text, attributes: [
                    .font: UIFont.systemFont(ofSize: t.fontSize * scale),
                    .foregroundColor: UIColor(hex: t.colorHex),
                    .paragraphStyle: para,
                ])
                cg.saveGState()
                let c = map(CGPoint(x: t.x, y: t.y))
                cg.translateBy(x: c.x, y: c.y)
                cg.rotate(by: t.rotation)
                attr.draw(in: CGRect(x: -w / 2 + 8 * scale, y: -h / 2 + 8 * scale,
                                     width: w - 16 * scale, height: h))
                cg.restoreGState()
            }
        }
    }

    /// Render to single-page PDF data.
    static func pdf(template: PageTemplate, drawing: PKDrawing,
                    stickers: [StickerItem], textBoxes: [TextBoxItem]) -> Data {
        let img = image(template: template, drawing: drawing,
                        stickers: stickers, textBoxes: textBoxes, outputWidth: 1400)
        let bounds = CGRect(origin: .zero, size: img.size)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { ctx in
            ctx.beginPage()
            img.draw(in: bounds)
        }
    }
}
