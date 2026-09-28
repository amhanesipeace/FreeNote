# FreeNote 📝

[![CI](https://github.com/amhanesipeace/FreeNote/actions/workflows/ci.yml/badge.svg)](https://github.com/amhanesipeace/FreeNote/actions/workflows/ci.yml)

A **100% free** digital notebook for iPad & iPhone — no subscriptions, no
paywalls, no ads, no accounts, no cloud. Your notes live only on your device.

Built with **SwiftUI** and Apple's **PencilKit**, so markup is first-class:
pen / pencil / marker / eraser, Apple Pencil pressure & tilt, colours & widths,
lasso selection, and undo — all native.

> **Status: v0.1 — working markup notebook.** Create notes, write/draw on a
> large zoomable canvas with the full PencilKit tool set, and everything
> auto-saves locally. Infinite canvas, stickers, and more are on the roadmap.

## Features (v0.1)

- ✍️ **Markup canvas** — PencilKit: pen, pencil, marker, highlighter, eraser,
  colour/width picker, lasso, undo/redo. Works with Apple Pencil or finger.
- 🗂️ **Notes** — create, open, rename, delete; newest-modified first.
- 💾 **Auto-save** — debounced local saves; one drawing file per note.
- 🔍 **Large zoomable/pannable canvas** (3000×4000) — pinch to zoom, drag to pan.
- 🔒 **100% local & private** — Documents directory only. No network code at all.

## Build & run

Requires a Mac with **Xcode 17+**. The `.xcodeproj` is generated from
`project.yml` (via [XcodeGen](https://github.com/yonabu/XcodeGen)) so it stays
out of version control.

```bash
brew install xcodegen        # once
cd FreeNote
xcodegen generate            # creates FreeNote.xcodeproj
open FreeNote.xcodeproj       # then press ⌘R to run
```

In Xcode, pick an **iPad simulator** (or your own iPad) and Run. To run on your
own device for free, select it, set your Apple ID as the signing team, and
Xcode installs a 7-day build — no paid account needed.

## Testing

The persistence layer (`NoteStore`) is unit-tested with XCTest — notes CRUD,
drawing/template/sticker round-trips, and file cleanup on delete. Tests inject a
temp directory so they never touch real data. CI runs them on every push.

```bash
xcodegen generate
xcodebuild test -scheme FreeNote -destination 'platform=iOS Simulator,name=iPad (A16)'
```

## Architecture

```
FreeNoteApp.swift    App entry; owns the shared NoteStore
Note.swift           Note model (metadata; drawing bytes stored separately)
NoteStore.swift      Persistence: notes index (JSON) + per-note drawing files
NoteListView.swift   Home screen: list, create, rename, delete
NoteEditorView.swift Hosts the canvas for one note; debounced auto-save
CanvasView.swift     UIViewRepresentable wrapping PKCanvasView + PKToolPicker
```

## Roadmap

1. ✅ v0.1 — markup notebook (PencilKit) + local persistence
2. True **infinite canvas** (unbounded, tiled) instead of a fixed large size
3. ✅ **Images & photos** on the canvas (import, move, resize)
4. ✅ **Custom stickers** — colourful SF-Symbol stickers, drag/resize/rotate
5. ✅ Text boxes — typed text alongside handwriting
6. ✅ Page **templates** — blank, lined, grid, dotted
7. **PDF import** (annotate PDFs) and **export** (share notes as PDF/PNG)
8. ✅ Folders & search

## License

MIT — free for everyone, forever.
