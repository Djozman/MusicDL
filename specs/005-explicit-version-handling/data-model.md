# Data Model: Explicit Version Recognition & UI Revamp

## Entities

### SearchResult
Existing result dict extended with explicit status:

- `type`: `"track"` | `"album"`
- `title`: String
- `artist`: String
- `album`: String
- `subtitle`: String (album label, may be empty)
- `artwork_url`: String
- `track_url`: String — resolvable per-variant URL (e.g., the explicit Spotify track;
  feeds the existing download pipeline)
- `source`: `"spotify"` | `"itunes"` | `"deezer"`
- `is_explicit`: `true` | `false` | `null` — explicit/clean flag from provider
  (nullable; `null` = unknown per FR-005)

### ExplicitStatus (derived, frontend display)
- `explicit` (is_explicit == true) → "Explicit"
- `clean` (is_explicit == false) → "Clean / Non-explicit"
- `unknown` (is_explicit == null) → "Unknown"

### TidalTrackRef (from search, FR-007)
A Tidal track ID derived from a selected search result so its download routes to the
Tidal HiRes source (96 kHz explicit):
- `tidal_track_id`: String — numeric Tidal track ID (e.g. `263828941`)
- `source`: `"tidal_mirror"` — derived via `TidalMirrorAdapter.search()` text match
- `title` / `artist`: the matched Tidal track's identity (for validation)

## Relationships

- **SearchResult** → **TrackMetadata**: a `SearchResult` row corresponds to one resolved
  track; `track_url` selects the specific explicit/clean variant to download.
- **SearchResult** → **TidalTrackRef**: a selected search result is enriched by querying
  the Tidal mirror text search (title/artist), producing a TidalTrackRef whose Tidal ID
  feeds the HiRes download pipeline (the same 96 kHz explicit a pasted Tidal link yields,
  FR-007).
- **ExplicitStatus** is a pure view over `SearchResult.is_explicit`; no separate storage.

## Ordering & Dedup Rule

- Search results are sorted explicit-first: `is_explicit == true` top, `null` (unknown)
  middle, `is_explicit == false` (clean) bottom (FR-002a).
- Dedup keeps the explicit↔clean variant distinction: two rows are duplicates only if
  they share `(normalized title, normalized artist, is_explicit)` — preserving both the
  explicit and clean editions of the same track as separate rows.

## Validation Rules

- `is_explicit` MUST be `true`, `false`, or absent (treated as `null`/unknown).
- A track with absent/`null` `is_explicit` MUST be presented as "unknown", never guessed.
- A `TidalTrackRef` with no Tidal ID (mirror search found nothing) MUST fall back to the
  search result's original `track_url` rather than failing the whole download.

## State Transitions

`query` → `search(q)` → `results[]` (each with `is_explicit`) | `error`
`results` → (tap variant row) → `track_url` → existing download flow → `DownloadStatus.*`
`tap` → (FR-007) `resolve_track.py <title> <artist> <url>` → `{tidal_track_id}` | original
`track_url` → HiRes download flow