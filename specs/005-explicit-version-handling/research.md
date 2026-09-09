# Research: Explicit Version Recognition & UI Revamp

## Decision: Surface `is_explicit` in the search result contract
- **Rationale**: The backend `TrackMetadata` already carries `is_explicit:
  Optional[bool]` (True = explicit, False = clean/edited, None = unknown — see
  `antra/core/models.py`). Spotify's `_parse_track()` already sets it from the
  `explicit` field on the raw track item. The only gap is that `search_music()` in
  `antra/core/spotify.py` collapses results into lightweight dicts
  (`{type, title, artist, album, artwork_url, track_url, source}`) that drop the flag.
  We add `is_explicit` to those dicts and carry it through `search.py` to the Swift app.
- **Alternatives considered**: Re-deriving explicitness client-side heuristically from
  title text ("clean", "edited") — unreliable and duplicative of provider data; adding a
  new backend provider — out of scope and violates Simplicity.

## Decision: Keep the explicit/non-explicit pair as separate results
- **Rationale**: Providers index explicit and clean editions as distinct track items with
  distinct IDs. The user wants both surfaced and separately downloadable with no
  auto-preference (clarification Q1). Keeping them as separate search-result rows with an
  Explicit/Clean label is the minimal change; `track_url` already points at the
  resolvable, per-variant Spotify URL which feeds the existing `download.py` unchanged.
- **Alternatives considered**: A single row with a sub-menu to pick the variant — higher
  UI complexity and more new navigation, and does not match the requested "explicit at
  top, non-explicit at bottom" ordering (clarification Q3).

## Decision: Order explicit versions above non-explicit ones in results
- **Rationale**: Directly implements clarification Q3 ("prioritize explicit search
  results and at the bottom non-explicit versions"). A stable secondary sort by
  `is_explicit` desc (True first, then unknown, then False) is deterministic and matches
  user intent.
- **Alternatives considered**: Ordering by provider rank or popularity — fails the stated
  requirement and could re-hide the explicit variants the user is after.

## Decision: Unknown explicit status degrades to "unknown", never guessed
- **Rationale**: FR-005 requires that when providers do not expose a flag (e.g., the
  anonymous iTunes fallback), the system displays "unknown" rather than guessing. This
  preserves correctness over vanity. `None` maps to an explicit "unknown" indicator.
- **Alternatives considered**: Defaulting unknown to "clean" — mislabels tracks and
  violates FR-005.

## Decision: Adaptive light/dark UI revamp
- **Rationale**: Clarification Q2 selected "follow system light/dark automatically."
  SwiftUI colors based on semantic assets (`Color(NSColor...windowBackgroundColor)`,
  `Color.accentColor`, dynamic system colors) adapt by default. The revamp focuses on
  spacing/typography hierarchy and consistent semantic colors rather than hard-coded
  appearance, so adaptive theming comes essentially for free.
- **Alternatives considered**: A hard-coded dark mode (option A) — rejected by user;
  a manual light/dark toggle (option D) — unnecessary complexity.

## Decision: Reuse existing helper/CLI boundary for the Swift frontend
- **Rationale**: `BackendService` already shells out to `search.py`, `preview.py`, and
  `download.py` over the JSON line protocol. Adding the explicit field is purely
  additive to the JSON, so the client remains agnostic and no new transport is needed.
- **Alternatives considered**: A bespoke API server — overkill for a single-user desktop
  app and violates the Simplicity principle.

## Decision: Add new small backend helpers (kept minimal)
- **Rationale**: Explicit propagation and the Tidal-ID-from-search system are additive to
  the existing layout. No new top-level module is created.
- **Alternatives considered**: A dedicated `ExplicitVersion` abstraction module —
  unnecessary given the flag already exists on `TrackMetadata`.

## Decision: Fetch a Tidal track ID from a search via the Tidal mirror (FR-007)
- **Rationale**: To let a search result download the same 96 kHz explicit master a pasted
  Tidal link yields, `resolve_track.py` runs `TidalMirrorAdapter.search()` (title/artist)
  against the configured Tidal mirror (endpoint manifest) and returns the matched Tidal
  track ID. Verified live: "Walk Em Down" → Tidal ID `263828941` (`src=tidal_mirror`).
- **Alternatives considered**: Odesli/song.link cross-platform resolution — rejected
  because the public API returned 401 (needs an API key that isn't configured) and it did
  not return a Tidal ID for the bare title/artist case.

## Decision: Take the first title+artist match, no confirmation (FR-010)
- **Rationale**: US3 (FR-008/FR-009) requires search and paste-link to be equivalent. The
  first (top-ranked) exact title+artist result from `TidalMirrorAdapter.search()` is taken
  as the intended track with no confirmation step, so a search selection resolves to the
  same Tidal ID (e.g. `263828941`) a pasted link would — with no extra UI latency or
  friction. Matches the project Simplicity principle.
- **Alternatives considered**: Confirming the resolved track when title/artist differ
  slightly (rejected — adds UI complexity and diverges from paste-link equivalence);
  exact-match-only gating (rejected — over-restricts and can fail on minor metadata
  variations); a manual mapping picker (rejected — violates Simplicity).

## Decision: Quality parity between search and paste-link (US3 / FR-008, FR-009)
- **Rationale**: SC-005 makes sample rate (96 kHz), codec (FLAC), and explicit status
  identical whether a track comes from search or a pasted link. Because a search resolves
  to the same Tidal track ID via FR-010/FR-007 and routes through the same HiRes
  `download.py` pipeline as a pasted link, the delivered file's specs match by
  construction — no separate 44.1 kHz MP3 fallback path for search.
- **Alternatives considered**: Keeping a lower-bitrate fallback source for search results
  (rejected — violates FR-008/FR-009 and is the reported bug).