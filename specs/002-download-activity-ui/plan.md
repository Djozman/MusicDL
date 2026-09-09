# Implementation Plan: Download Activity UI with Track Selection

**Branch**: `002-download-activity-ui` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-download-activity-ui/spec.md`

## Summary

Enhance the SwiftMusicDL frontend to (1) show adaptive download status text that
distinguishes single-track vs. album/playlist downloads, (2) surface a selectable
checklist of tracks when the user pastes an album/playlist link, and (3) display a
per-track progress bar for each selected track during multi-track downloads.

## Technical Context

**Language/Version**: Swift 5.9+ / SwiftUI (existing frontend); Python 3.14 (existing backend)

**Primary Dependencies**: SwiftUI, Foundation (URLSession/Process); existing antra backend (no new deps)

**Storage**: N/A (filesystem `~/Music`)

**Testing**: Existing `swift build`; manual/UI validation via `quickstart.md`

**Target Platform**: macOS 13.0+

**Project Type**: Desktop app frontend

**Performance Goals**: Status text and per-track bars update in real time as backend emits events

**Constraints**: Lightweight UI; must parse backend JSON event stream without blocking main thread

**Scale/Scope**: 1 frontend view hierarchy; several new SwiftUI views + view-model logic

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **II. Lightweight Client Agnosticism** — PASS: UI stays decoupled from backend; the
  frontend parses backend JSON events only.
- **V. Simplicity & Performance** — PASS: adds a few SwiftUI views; no new heavy dependencies.

## Project Structure

### Documentation (this feature)

```text
specs/002-download-activity-ui/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

Existing Swift package at repo root:

```text
SwiftMusicDL/
├── Models/
│   ├── TrackMetadata.swift       # Add ContentType, selectable tracks
│   └── DownloadState.swift       # Add per-track progress states
├── ViewModels/
│   └── MainViewModel.swift       # Add track selection + per-track progress publishing
├── Views/
│   ├── ContentView.swift         # Route preview → checklist → download UI
│   ├── PreviewCardView.swift     # Existing single-track preview
│   ├── TrackSelectionView.swift  # NEW: album/playlist checklist
│   └── TrackProgressBarView.swift# NEW: per-track progress bar
└── Services/
    └── BackendService.swift      # Parse per-track download events
```

**Structure Decision**: Reuse the existing single Swift package layout; add 2 new
SwiftUI views and extend existing models/view-model/service.