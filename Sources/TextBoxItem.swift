import CoreGraphics
import Foundation

/// A typed text box placed on a note's canvas — movable, resizable (font),
/// rotatable, and editable inline. Position is the box's *centre* in canvas
/// coordinates so it scrolls with the page.
struct TextBoxItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var colorHex: String
    var fontSize: CGFloat
    var width: CGFloat         // wrapping width; height grows with content
    var x: CGFloat             // centre X in canvas coordinates
    var y: CGFloat             // centre Y in canvas coordinates
    var rotation: CGFloat      // radians

    init(id: UUID = UUID(), text: String = "Text",
         colorHex: String = "#1C1C1E", fontSize: CGFloat = 34,
         width: CGFloat = 360, x: CGFloat, y: CGFloat, rotation: CGFloat = 0) {
        self.id = id
        self.text = text
        self.colorHex = colorHex
        self.fontSize = fontSize
        self.width = width
        self.x = x
        self.y = y
        self.rotation = rotation
    }
}
