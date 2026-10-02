import XCTest
@testable import FreeNote

/// Tests for the persistence layer. Each test uses a fresh temp directory, so
/// they are isolated and never touch real app data.
final class NoteStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeStore() -> NoteStore { NoteStore(directory: tempDir) }

    // MARK: - Notes list

    func testAddNoteInsertsNewestFirst() {
        let store = makeStore()
        store.addNote(title: "First")
        store.addNote(title: "Second")
        XCTAssertEqual(store.notes.count, 2)
        XCTAssertEqual(store.notes.first?.title, "Second")
    }

    func testNotesPersistAcrossStores() {
        let a = makeStore()
        a.addNote(title: "Keep me")
        // A brand new store over the same directory should reload it.
        let b = NoteStore(directory: tempDir)
        XCTAssertEqual(b.notes.count, 1)
        XCTAssertEqual(b.notes.first?.title, "Keep me")
    }

    func testRename() {
        let store = makeStore()
        let note = store.addNote(title: "Old")
        store.rename(note, to: "New")
        XCTAssertEqual(store.notes.first?.title, "New")
    }

    func testRenameEmptyBecomesUntitled() {
        let store = makeStore()
        let note = store.addNote(title: "Something")
        store.rename(note, to: "")
        XCTAssertEqual(store.notes.first?.title, "Untitled")
    }

    func testDeleteRemovesNoteAndFiles() {
        let store = makeStore()
        let note = store.addNote(title: "Doomed")
        store.saveDrawingData(Data([1, 2, 3]), for: note)
        let drawingPath = store.drawingURL(for: note).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: drawingPath))

        store.deleteNotes(at: IndexSet(integer: 0))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: drawingPath))
    }

    // MARK: - Drawing data

    func testDrawingDataRoundTrip() {
        let store = makeStore()
        let note = store.addNote()
        let bytes = Data([9, 8, 7, 6])
        store.saveDrawingData(bytes, for: note)
        XCTAssertEqual(store.loadDrawingData(for: note), bytes)
    }

    func testSaveDrawingMovesNoteToTop() {
        let store = makeStore()
        let first = store.addNote(title: "A")
        store.addNote(title: "B")             // B now on top
        store.saveDrawingData(Data([1]), for: first)  // touching A bumps it up
        XCTAssertEqual(store.notes.first?.id, first.id)
    }

    // MARK: - Templates

    func testTemplateDefaultsToLined() {
        let store = makeStore()
        let note = store.addNote()
        XCTAssertEqual(note.pageTemplate, .lined)
    }

    func testSetTemplatePersists() {
        let store = makeStore()
        let note = store.addNote()
        store.setTemplate(.grid, for: note)
        let reloaded = NoteStore(directory: tempDir)
        XCTAssertEqual(reloaded.notes.first?.pageTemplate, .grid)
    }

    // MARK: - Stickers

    func testStickersRoundTrip() {
        let store = makeStore()
        let note = store.addNote()
        let stickers = [
            StickerItem(symbol: "star.fill", x: 10, y: 20),
            StickerItem(symbol: "heart.fill", colorHex: "#FF0000", x: 30, y: 40, size: 200),
        ]
        store.saveStickers(stickers, for: note)
        XCTAssertEqual(store.loadStickers(for: note), stickers)
    }

    func testStickerImageSavedAndReferenced() {
        let store = makeStore()
        let id = UUID()
        let file = store.saveStickerImage(Data([0xAB, 0xCD]), id: id)
        XCTAssertTrue(file.contains(id.uuidString))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: tempDir.appendingPathComponent(file).path))
    }

    // MARK: - Pages

    func testNewNoteHasOnePage() {
        let store = makeStore()
        XCTAssertEqual(store.addNote().pages, 1)
    }

    func testAddPageIncrementsCountAndPersists() {
        let store = makeStore()
        let note = store.addNote()
        XCTAssertEqual(store.addPage(to: note), 2)
        XCTAssertEqual(store.addPage(to: note), 3)
        XCTAssertEqual(NoteStore(directory: tempDir).notes.first?.pages, 3)
    }

    func testPerPageContentIsIsolated() {
        let store = makeStore()
        let note = store.addNote()
        store.addPage(to: note)                       // now 2 pages
        store.saveDrawingData(Data([1]), for: note, page: 0)
        store.saveDrawingData(Data([2]), for: note, page: 1)
        store.saveStickers([StickerItem(symbol: "star.fill", x: 1, y: 1)],
                           for: note, page: 1)

        XCTAssertEqual(store.loadDrawingData(for: note, page: 0), Data([1]))
        XCTAssertEqual(store.loadDrawingData(for: note, page: 1), Data([2]))
        XCTAssertTrue(store.loadStickers(for: note, page: 0).isEmpty)
        XCTAssertEqual(store.loadStickers(for: note, page: 1).count, 1)
    }

    func testDeleteRemovesAllPages() {
        let store = makeStore()
        let note = store.addNote()
        store.addPage(to: note)
        store.saveDrawingData(Data([1]), for: note, page: 0)
        store.saveDrawingData(Data([2]), for: note, page: 1)
        let p1 = store.drawingURL(for: note, page: 1).path
        store.deleteNotes(at: IndexSet(integer: 0))
        XCTAssertFalse(FileManager.default.fileExists(atPath: p1))
    }

    // MARK: - Folders

    func testSetFolderPersistsAndListsFolders() {
        let store = makeStore()
        let a = store.addNote(title: "A")
        let b = store.addNote(title: "B")
        store.setFolder("Work", for: a)
        store.setFolder("Personal", for: b)
        XCTAssertEqual(store.folders, ["Personal", "Work"])   // sorted
        let reloaded = NoteStore(directory: tempDir)
        XCTAssertEqual(Set(reloaded.notes.compactMap(\.folder)), ["Work", "Personal"])
    }

    func testSetFolderBlankClearsIt() {
        let store = makeStore()
        let note = store.addNote()
        store.setFolder("Temp", for: note)
        store.setFolder("   ", for: note)                     // whitespace clears
        XCTAssertNil(store.notes.first?.folder)
        XCTAssertTrue(store.folders.isEmpty)
    }

    // MARK: - Text boxes

    func testTextBoxesRoundTrip() {
        let store = makeStore()
        let note = store.addNote()
        let boxes = [
            TextBoxItem(text: "Hello", x: 10, y: 20),
            TextBoxItem(text: "World", colorHex: "#FF0000", fontSize: 50, x: 30, y: 40),
        ]
        store.saveTextBoxes(boxes, for: note)
        XCTAssertEqual(store.loadTextBoxes(for: note), boxes)
    }

    func testTextBoxesEmptyByDefault() {
        let store = makeStore()
        let note = store.addNote()
        XCTAssertTrue(store.loadTextBoxes(for: note).isEmpty)
    }

    func testDeleteNoteRemovesStickerPhotoFiles() {
        let store = makeStore()
        let note = store.addNote()
        let file = store.saveStickerImage(Data([1, 2]), id: UUID())
        store.saveStickers([StickerItem(imageFile: file, x: 0, y: 0)], for: note)
        let path = tempDir.appendingPathComponent(file).path
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        store.deleteNotes(at: IndexSet(integer: 0))
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
