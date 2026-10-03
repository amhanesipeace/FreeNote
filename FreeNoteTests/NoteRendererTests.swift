import XCTest
import PencilKit
@testable import FreeNote

/// Tests for the note renderer — verifies multi-page PDF export produces the
/// right number of PDF pages (no UI needed).
final class NoteRendererTests: XCTestCase {

    private func page() -> NoteRenderer.PageContent {
        NoteRenderer.PageContent(template: .lined, drawing: PKDrawing(),
                                 stickers: [], textBoxes: [])
    }

    private func pdfPageCount(_ data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData),
              let doc = CGPDFDocument(provider) else { return 0 }
        return doc.numberOfPages
    }

    func testMultiPagePdfHasOnePagePerContent() {
        let data = NoteRenderer.pdf(pages: [page(), page(), page()])
        XCTAssertEqual(pdfPageCount(data), 3)
    }

    func testSinglePagePdf() {
        let data = NoteRenderer.pdf(template: .grid, drawing: PKDrawing(),
                                    stickers: [], textBoxes: [])
        XCTAssertEqual(pdfPageCount(data), 1)
    }

    func testImageRendersNonEmpty() {
        let img = NoteRenderer.image(template: .dotted, drawing: PKDrawing(),
                                     stickers: [], textBoxes: [], outputWidth: 200)
        XCTAssertEqual(img.size.width, 200, accuracy: 1)
        XCTAssertGreaterThan(img.size.height, 0)
    }
}
