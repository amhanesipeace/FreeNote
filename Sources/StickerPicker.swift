import SwiftUI

/// A grid of colourful SF Symbol "stickers" to drop onto the page.
/// Tapping one calls `onPick` with the symbol name and its colour.
struct StickerPicker: View {
    var onPick: (_ symbol: String, _ colorHex: String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(StickerLibrary.stickers, id: \.symbol) { item in
                        Button { onPick(item.symbol, item.color) } label: {
                            Image(systemName: item.symbol)
                                .font(.system(size: 34))
                                .foregroundStyle(Color(UIColor(hex: item.color)))
                                .frame(width: 64, height: 64)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
