# Implementation Plan: Lightweight Swift Frontend with Central Download Bar

## Technical Context

### Language & Runtime
- **Swift 5.9+ / SwiftUI** for macOS (and/or iOS) desktop/mobile frontend app.
- **Python 3.10+** backend runtime for executing music downloads and metadata resolution.

### Libraries & Frameworks
- SwiftUI for declarative UI.
- Foundation (URLSession, Process/ProcessRunner or HTTP communication with local backend or direct execution/CLI bridge).

### Project Structure
- `SwiftMusicDL/` (New Swift project directory)
  - `Views/`: Central search/paste bar, preview card, download confirmation dialog.
  - `ViewModels/`: State management, communication with backend/API.
  - `Models/`: Track metadata, download status.
  - `Services/`: Backend runner or HTTP client service.

### Constitution Check
- Compliance with backend-first reliability and lightweight client agnosticism.
- Clean separation between frontend presentation and backend music downloading engine.

## Research & Architecture (`research.md`)

- **Decision**: Build a native macOS/iOS SwiftUI lightweight application that invokes or communicates with the existing Python backend (`antra`).
- **Rationale**: SwiftUI provides a fast, modern, minimalist interface ideal for a centered search bar and preview card layout.
- **Alternatives Considered**: Electron, web-based UI (SwiftUI is lighter and natively integrates with macOS desktop apps).

## Data Model (`data-model.md`)

- **DownloadRequest**: `url: String`, `source: String`
- **TrackMetadata**: `title: String`, `artist: String`, `album: String`, `artworkURL: String?`, `duration: TimeInterval?`
- **DownloadStatus**: `idle`, `fetchingMetadata`, `previewReady`, `downloading`, `completed`, `failed(String)`

## Interface Contracts (`contracts/`)
- Backend JSON CLI or local IPC contract:
  - Input: `{ "url": "https://..." }`
  - Metadata Output: `{ "title": "...", "artist": "...", "artwork_url": "...", "status": "success" }`
  - Download Command: Python backend invoked with output path `~/Music` (`users/amm/music`).

## Quickstart Guide (`quickstart.md`)
- Prerequisites: Swift 5.9+, Xcode, Python 3.10+ environment installed.
- Build/Run: Open Swift project in Xcode or build via `swift build` / `swift run`.
- Test workflow: Paste link -> View preview -> Confirm download -> Verify file appears in `~/Music`.
