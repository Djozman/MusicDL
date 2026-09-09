# Implementation Plan: Explicit Version Recognition & UI Revamp

**Branch**: `005-explicit-version-handling` | **Date**: 2026-08-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-explicit-version-handling/spec.md`

## Summary

Backend search results currently omit the explicit/clean flag that providers already
report (`TrackMetadata.is_explicit` exists but `search_music()` drops it), so the user
silently receives whichever version ranks first — typically the clean one. This feature
(1) carries the explicit status through the search contract, (2) surfaces each variant
as a distinct, labeled, separately-downloadable choice with explicit versions ordered
above non-explicit ones, and (3) revamps the SwiftUI frontend to a spacious, adaptive
(light/dark) modern design without changing the downloader's CLI.

The feature also adds FR-007: a system that derives a **Tidal track ID from a search
result** (via the Tidal mirror's text search), so the same 96 kHz explicit master the
mirror serves for a pasted Tidal link is downloadable straight from a search result —
not just from a pasted link. This realizes **User Story 3 (FR-008/FR-009)**: search and
paste-link must be equivalent (same source track, same quality, no 44.1 kHz MP3 fallback).
**FR-010** pins the resolution rule: the *first* title+artist match from the Tidal mirror
is taken as the intended track, with no confirmation step — keeping parity with a pasted
link while avoiding wrong-track downloads.

## Technical Context

**Language/Version**: Python 3.10+ (backend); SwiftUI / Swift 5.9+ (frontend)

**Primary Dependencies**: `antra` backend package (SpotifyClient + iTunes Search API +
Deezer public); `antra.sources.tidal_mirror.TidalMirrorAdapter` (text search → Tidal track
ID, HiRes 96 kHz); SwiftUI, Foundation, Combine (frontend, no new frameworks)

**Storage**: Filesystem for downloaded audio (`~/Music`); no database; Tidal mirror
endpoint + API key from the endpoint manifest (`ANTRA_ENDPOINT_MANIFEST_URL` / cache)

**Testing**: pytest (backend pipeline); XCTest (Swift frontend) per constitution

**Target Platform**: macOS (SwiftUI app); Python CLI remains cross-platform

**Project Type**: desktop app (macOS SwiftUI) + Python CLI backend

**Performance Goals**: No perceptible latency added to search; results render instantly
on tap; artwork already cached/streamed via `AsyncImage`

**Constraints**: Reuse existing helper scripts (`search.py`, `preview.py`, `download.py`)
and the existing download/resolve pipeline without duplicating backend logic

**Scale/Scope**: Single-user desktop app; ~15 search results; 1 SwiftUI app + Python abs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Downloader-First Reliability**: Explicit/clean detection and variant download
  must remain robust and source-agnostic. PASS — reuses existing provider flags; no new
  sources introduced.
- **II. Lightweight Client Agnosticism**: Client stays decoupled via JSON/CLI; the
  explicit flag is added to the existing search JSON contract, keeping the Swift client
  thin. PASS.
- **III. Test-Driven Verification (NON-NEGOTIABLE)**: New explicit propagation and
  variant selection MUST be covered by automated tests; this is a hard gate. PASS —
  plan includes contract + backend unit tests and XCTest for ordering/labeling.
- **IV. Observability & Graceful Error Handling**: Unknown explicit status must degrade
  to "unknown" (not guessed). PASS.
- **V. Simplicity & Performance**: No new dependencies or redundant abstraction; reuses
  existing models and pipeline. PASS.

No violations; no Complexity Tracking needed.

*Post-design re-check (after Phase 1):* the design carries `is_explicit` through the
existing search contract, orders variants in the backend, revamps the SwiftUI views, and
adds a `resolve_track.py` helper that fetches a Tidal track ID via `TidalMirrorAdapter`
text search so the Tidal HiRes (96 kHz explicit) source is reachable from a search
result. US3 (FR-008/FR-009) guarantees the search download matches the pasted-link file
(sample rate/codec/explicit) by routing through the same HiRes pipeline; FR-010 takes the
first title+artist match with no confirmation. All additive; no new third-party
dependency. Verified: `TidalMirrorAdapter` searched "Walk Em Down" → Tidal ID `263828941`.
Constitution gates remain PASS.

## Project Structure

### Documentation (this feature)

```text
specs/005-explicit-version-handling/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Backend (Python) — modified, plus two new helpers
search.py                      # merge Spotify/iTunes/Deezer; dedupe explicit/clean; sort explicit first
resolve_track.py               # NEW: search-result → Tidal track ID via TidalMirrorAdapter.search()
antra/utils/resolve_best_url.py# NOT used for Tidal (Odesli needs a key) — retained only as fallback
antra/sources/deezer_public.py # NEW: public Deezer search (unauthenticated, explicit flag)
antra/utils/search_refine.py   # NEW: derivative filter + explicit-title inference + edition dedupe
antra/utils/search_ordering.py # NEW: stable explicit-first ordering
antra/core/spotify.py          # search_music: is_explicit on results; anonymous/Spotify fallback

# Frontend (SwiftUI) — modified
SwiftMusicDL/
├── Models/
│   ├── SearchResult.swift     # explicitStatus field + display ordering
│   └── TrackMetadata.swift    # isExplicit passthrough for preview
├── Services/
│   └── BackendService.swift   # decode is_explicit; route search download via resolve_track
├── ViewModels/
│   └── SearchViewModel.swift  # explicit-first ordering + Tidal-ID download flow
└── Views/
    ├── ContentView.swift      # revamped layout + theme
    ├── SearchResultsView.swift# explicit/clean label + rework
    ├── PreviewCardView.swift  # revamped
    ├── TrackSelectionView.swift
    ├── TrackProgressBarView.swift
    └── ...

# Tests
tests/                         # pytest additions for explicit propagation/ordering + Deezer
Tests/SwiftMusicDLModels/      # XCTest additions for labeling/ordering
```

**Structure Decision**: Existing single-project layout (Python backend + SwiftUI app in
one repo). The Tidal-ID-from-search system (FR-007) is additive: a new `resolve_track.py`
helper shells to `TidalMirrorAdapter.search()` (proven to return ID `263828941` for
"Walk Em Down") and hands the Tidal ID to the existing HiRes download pipeline. No new
top-level modules or new third-party dependencies.

## Complexity Tracking

> Not filled — no Constitution violations to justify.