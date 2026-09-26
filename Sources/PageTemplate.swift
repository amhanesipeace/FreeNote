import UIKit

/// The paper style drawn behind the ink: blank, lined, grid, or dotted.
///
/// Each style is rendered as a small **tileable** image, then used as a
/// pattern colour on a background view sized to the whole canvas — so the
/// paper scrolls together with the drawing and stays memory-cheap (we tile a
/// tiny image instead of allocating one giant page bitmap).
enum PageTemplate: String, Codable, CaseIterable, Identifiable {
    case blank, lined, grid, dotted

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .blank:  return "rectangle"
        case .lined:  return "line.3.horizontal"
        case .grid:   return "grid"
        case .dotted: return "circle.grid.3x3"
        }
    }

    /// Size of one repeating tile, in points.
    private var tile: CGSize {
        switch self {
        case .blank:  return CGSize(width: 8, height: 8)
        case .lined:  return CGSize(width: 8, height: 36)   // rule every 36pt
        case .grid:   return CGSize(width: 32, height: 32)  // 32pt squares
        case .dotted: return CGSize(width: 26, height: 26)  // dots every 26pt
        }
    }

    /// A tileable image: white page plus this style's rule marks.
    func patternImage() -> UIImage {
        let size = tile
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let line = UIColor(white: 0.80, alpha: 1)
            line.setStroke()
            line.setFill()
            cg.setLineWidth(1)

            switch self {
            case .blank:
                break
            case .lined:
                cg.move(to: CGPoint(x: 0, y: size.height - 0.5))
                cg.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                cg.strokePath()
            case .grid:
                // bottom + right edges; adjacent tiles complete the grid
                cg.move(to: CGPoint(x: 0, y: size.height - 0.5))
                cg.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                cg.move(to: CGPoint(x: size.width - 0.5, y: 0))
                cg.addLine(to: CGPoint(x: size.width - 0.5, y: size.height))
                cg.strokePath()
            case .dotted:
                cg.fillEllipse(in: CGRect(x: 0, y: 0, width: 2, height: 2))
            }
        }
    }

    /// A pattern colour for a background view (blank = plain white).
    func patternColor() -> UIColor {
        self == .blank ? .white : UIColor(patternImage: patternImage())
    }
}
