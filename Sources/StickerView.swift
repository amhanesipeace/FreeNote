import UIKit

/// A single sticker rendered as a movable/resizable/rotatable SF Symbol image.
///
/// It carries its own pan / pinch / rotation gesture recognizers. Because it is
/// a subview *on top* of the PencilKit drawing, touches that begin on the
/// sticker are handled here (move it) rather than drawing ink — so stickers and
/// handwriting coexist without a mode switch.
final class StickerView: UIImageView {
    let stickerID: UUID
    private let symbol: String
    private let colorHex: String
    private let imageFile: String?
    private var aspect: CGFloat

    /// Called (with the updated geometry) whenever the user finishes a gesture.
    var onChange: ((StickerView) -> Void)?
    /// Called when the user taps the sticker (used to offer delete).
    var onTap: ((StickerView) -> Void)?

    init(item: StickerItem) {
        self.stickerID = item.id
        self.symbol = item.symbol
        self.colorHex = item.colorHex
        self.imageFile = item.imageFile
        self.aspect = item.aspect
        super.init(frame: .zero)

        if let file = item.imageFile,
           let img = UIImage(contentsOfFile: AppPaths.documents
               .appendingPathComponent(file).path) {
            image = img                       // photo sticker: full colour
            contentMode = .scaleAspectFit
        } else {
            image = UIImage(systemName: item.symbol)?.withRenderingMode(.alwaysTemplate)
            tintColor = UIColor(hex: item.colorHex)
            contentMode = .scaleAspectFit
        }
        isUserInteractionEnabled = true

        bounds = CGRect(x: 0, y: 0, width: item.size, height: item.size * item.aspect)
        center = CGPoint(x: item.x, y: item.y)
        transform = CGAffineTransform(rotationAngle: item.rotation)

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
        addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(rotate(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Current geometry as a model item.
    func asItem() -> StickerItem {
        StickerItem(id: stickerID, symbol: symbol, colorHex: colorHex,
                    imageFile: imageFile, aspect: aspect,
                    x: center.x, y: center.y,
                    size: bounds.width, rotation: currentRotation())
    }

    /// Update geometry from a model item (used when syncing externally).
    func apply(_ item: StickerItem) {
        aspect = item.aspect
        bounds = CGRect(x: 0, y: 0, width: item.size, height: item.size * item.aspect)
        center = CGPoint(x: item.x, y: item.y)
        transform = CGAffineTransform(rotationAngle: item.rotation)
    }

    private func currentRotation() -> CGFloat { atan2(transform.b, transform.a) }

    var isInteracting: Bool {
        gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } ?? false
    }

    // MARK: - Gestures

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        guard let parent = superview else { return }
        let t = g.translation(in: parent)
        center = CGPoint(x: center.x + t.x, y: center.y + t.y)
        g.setTranslation(.zero, in: parent)
        if g.state == .ended { onChange?(self) }
    }

    @objc private func pinch(_ g: UIPinchGestureRecognizer) {
        if g.state == .changed {
            let newWidth = max(48, min(800, bounds.width * g.scale))
            bounds = CGRect(x: 0, y: 0, width: newWidth, height: newWidth * aspect)
            g.scale = 1
        } else if g.state == .ended {
            onChange?(self)
        }
    }

    @objc private func rotate(_ g: UIRotationGestureRecognizer) {
        transform = transform.rotated(by: g.rotation)
        g.rotation = 0
        if g.state == .ended { onChange?(self) }
    }

    @objc private func tap() { onTap?(self) }
}
