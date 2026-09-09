# Research: Download Activity UI with Track Selection

## Decision: Stream backend events for per-track progress
- **Rationale**: The antra backend (`json_cli.py`) already emits `track_started`,
  `track_resolved`, `track_download_attempt`, `track_completed` events on stdout as
  JSON lines. The Swift frontend can read stdout incrementally to update the UI live
  instead of polling.
- **Alternatives considered**: Shelling out and waiting for the whole run (no live
  progress), or introducing a HTTP server (heavier than needed for a local app).

## Decision: Reuse `playlist_loaded` event for album/playlist checklist
- **Rationale**: The backend already emits a `playlist_loaded` event with a `tracks`
  array (title, artist, duration). `preview.py` returns these same tracks. The
  checklist can be built from that existing metadata with no backend changes.
- **Alternatives considered**: Adding a new backend endpoint (unnecessary; data already exposed).

## Decision: Distinguish single vs. multi via content metadata
- **Rationale**: A single-track link yields `content_type == "SINGLE"` and 1 track;
  albums/playlists yield multiple tracks. Use title/album + the number of tracks to
  drive the adaptive copy.
- **Alternatives considered**: Inspecting the URL string pattern (fragile across sources).

## Decision: SwiftUI `AsyncImage` + `ProgressView` bar per track
- **Rationale**: Native, lightweight, keeps UI reactive without third-party libraries.