import UIKit

/// An inline-editable text box on the canvas.
///
/// It is a `UITextView` layered on top of the ink. When **not** editing, its own
/// touch handling is off so the container gestures (move / pinch-font / rotate /
/// tap-to-edit) work. Tapping enters edit mode (keyboard + a Done button);
/// finishing editing turns interaction back off and persists the text.
final class TextBoxView: UITextView, UITextViewDelegate {
    let boxID: UUID
    private let colorHex: String
    private var boxWidth: CGFloat

    var onChange: ((TextBoxView) -> Void)?

    private lazy var moveGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
    private lazy var scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
    private lazy var spinGesture = UIRotationGestureRecognizer(target: self, action: #selector(spin(_:)))
    private lazy var editTap = UITapGestureRecognizer(target: self, action: #selector(beginEditing))

    init(item: TextBoxItem) {
        self.boxID = item.id
        self.colorHex = item.colorHex
        self.boxWidth = item.width
        super.init(frame: .zero, textContainer: nil)

        text = item.text
        font = .systemFont(ofSize: item.fontSize)
        textColor = UIColor(hex: item.colorHex)
        backgroundColor = .clear
        isScrollEnabled = false           // grow to fit content
        textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        delegate = self
        setEditing(false)                 // start in "move" mode

        addGestureRecognizer(moveGesture)
        addGestureRecognizer(scaleGesture)
        addGestureRecognizer(spinGesture)
        addGestureRecognizer(editTap)

        layoutToFit()
        center = CGPoint(x: item.x, y: item.y)
        transform = CGAffineTransform(rotationAngle: item.rotation)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Size the box to its wrapping width and content height, keeping the centre.
    private func layoutToFit() {
        let saved = center
        let fit = sizeThatFits(CGSize(width: boxWidth, height: .greatestFiniteMagnitude))
        bounds = CGRect(x: 0, y: 0, width: boxWidth, height: max(44, fit.height))
        center = saved
    }

    func asItem() -> TextBoxItem {
        TextBoxItem(id: boxID, text: text, colorHex: colorHex,
                    fontSize: font?.pointSize ?? 34, width: boxWidth,
                    x: center.x, y: center.y, rotation: atan2(transform.b, transform.a))
    }

    func apply(_ item: TextBoxItem) {
        boxWidth = item.width
        font = .systemFont(ofSize: item.fontSize)
        text = item.text
        layoutToFit()
        center = CGPoint(x: item.x, y: item.y)
        transform = CGAffineTransform(rotationAngle: item.rotation)
    }

    var isInteracting: Bool {
        isFirstResponder ||
        [moveGesture, scaleGesture, spinGesture].contains {
            $0.state == .began || $0.state == .changed }
    }

    // MARK: - Edit mode

    private func setEditing(_ editing: Bool) {
        isEditable = editing
        isSelectable = editing
        // When not editing, our touches pass through to gestures (move mode).
        isUserInteractionEnabled = true
        moveGesture.isEnabled = !editing
        scaleGesture.isEnabled = !editing
        spinGesture.isEnabled = !editing
        editTap.isEnabled = !editing
    }

    @objc private func beginEditing() {
        setEditing(true)
        inputAccessoryView = doneToolbar()
        becomeFirstResponder()
    }

    private func doneToolbar() -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endEditingNow)),
        ]
        bar.sizeToFit()
        return bar
    }

    @objc private func endEditingNow() { resignFirstResponder() }

    func textViewDidChange(_ textView: UITextView) { layoutToFit() }

    func textViewDidEndEditing(_ textView: UITextView) {
        setEditing(false)
        onChange?(self)
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
            let newSize = max(14, min(160, (font?.pointSize ?? 34) * g.scale))
            font = .systemFont(ofSize: newSize)
            layoutToFit()
            g.scale = 1
        } else if g.state == .ended {
            onChange?(self)
        }
    }

    @objc private func spin(_ g: UIRotationGestureRecognizer) {
        transform = transform.rotated(by: g.rotation)
        g.rotation = 0
        if g.state == .ended { onChange?(self) }
    }
}
