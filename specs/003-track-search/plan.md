# Implementation Plan: Track Search & Download

**Branch**: `003-track-search` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

## Summary

Add a lightweight search feature to the SwiftUI app: a query box that searches the
backend's track-search (Spotify, falling back to the public iTunes Search API) and
renders matching tracks as a list (artwork, title, artist). Tapping a result feeds its
resolved track URL into the existing download flow so it downloads to `~/Music` via the
already-working `download.py` pipeline.

## Technical Context

**Language/Version**: Swift 5.9+ / SwiftUI (frontend); Python 3.14 (backend)

**Primary Dependencies**: Existing `SpotifyClient.search_track` (`antra/core/spotify.py`);
no new dependencies

**Storage**: None (results come from remote catalog)

**Testing**: `swift build`; manual/UI validation via `quickstart.md`

**Target Platform**: macOS 13.0+

**Project Type**: Desktop app frontend + small backend helper

**Performance Goals**: Search results appear within a few seconds of typing; tapping
reuses the existing download pathway

**Constraints**: Lightweight; reuse existing backend; no local database

**Scale/Scope**: One new backend helper (`search.py`), one new Swift search view, one
wire into existing download flow

## Constitution Check

*GATE checked against `.specify/memory/constitution.md`.*

- **II. Lightweight Client Agnosticism** — PASS: search stays a thin backend call; UI just
  renders JSON results.
- **V. Simplicity & Performance** — PASS: one backend helper + one Swift view; no new deps.

## Project Structure

### Documentation (this feature)

```text
specs/003-track-search/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
search.py                           # NEW backend helper: query -> JSON results
SwiftMusicDL/
├── Models/
│   └── SearchResult.swift          # NEW: search result model
├── Services/
│   └── BackendService.swift        # ADD searchTracks(_:) -> [SearchResult]
├── ViewModels/
│   └── MainViewModel.swift         # ADD search state + selectedResult()
│   └── SearchViewModel.swift       # NEW: search box → results
└── Views/
    ├── ContentView.swift           # ADD search section
    └── SearchResultsView.swift     # NEW: results list
```

**Structure Decision**: Reuse the existing single Swift package; add one backend helper
and one small Swift view + model + service method.