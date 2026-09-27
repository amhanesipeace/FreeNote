import CoreGraphics
import Foundation
import UIKit

/// A sticker placed on a note's canvas.
///
/// v0.1 stickers are **SF Symbols** — crisp, scalable, tintable vector icons
/// that render reliably on every device and in the Simulator (unlike emoji,
/// which the Simulator often shows as "tofu"). The same view layer will later
/// accept photo/image stickers too. Position is the sticker's *centre* in
/// canvas coordinates so it scrolls with the page.
struct StickerItem: Identifiable, Codable, Equatable {
    let id: UUID
    var symbol: String         // SF Symbol name
    var colorHex: String       // tint colour, e.g. "#FF3B30"
    var x: CGFloat             // centre X in canvas coordinates
    var y: CGFloat             // centre Y in canvas coordinates
    var size: CGFloat          // width == height, in points
    var rotation: CGFloat      // radians

    init(id: UUID = UUID(), symbol: String, colorHex: String = "#FF9500",
         x: CGFloat, y: CGFloat, size: CGFloat = 110, rotation: CGFloat = 0) {
        self.id = id
        self.symbol = symbol
        self.colorHex = colorHex
        self.x = x
        self.y = y
        self.size = size
        self.rotation = rotation
    }
}

/// A built-in palette of colourful SF Symbol "stickers" to get started.
enum StickerLibrary {
    /// (symbol name, tint colour) pairs.
    static let stickers: [(symbol: String, color: String)] = [
        ("star.fill", "#FFCC00"),        ("heart.fill", "#FF3B30"),
        ("flame.fill", "#FF9500"),       ("checkmark.seal.fill", "#34C759"),
        ("exclamationmark.triangle.fill", "#FF9500"),
        ("lightbulb.fill", "#FFCC00"),   ("pin.fill", "#FF2D55"),
        ("target", "#FF3B30"),           ("bolt.fill", "#FFCC00"),
        ("hand.thumbsup.fill", "#007AFF"),
        ("bookmark.fill", "#5856D6"),    ("crown.fill", "#FFCC00"),
        ("sparkles", "#AF52DE"),         ("leaf.fill", "#34C759"),
        ("cloud.fill", "#5AC8FA"),       ("moon.fill", "#5856D6"),
        ("sun.max.fill", "#FF9500"),     ("music.note", "#FF2D55"),
        ("gift.fill", "#FF3B30"),        ("face.smiling", "#FFCC00"),
        ("hand.raised.fill", "#FF9500"), ("arrow.right.circle.fill", "#007AFF"),
        ("questionmark.circle.fill", "#5856D6"), ("checkmark.circle.fill", "#34C759"),
    ]
}

extension UIColor {
    /// Create a colour from a "#RRGGBB" string (falls back to system orange).
    convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else {
            self.init(red: 1, green: 0.58, blue: 0, alpha: 1); return
        }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
