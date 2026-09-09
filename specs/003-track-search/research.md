# Research: Track Search & Download

## Decision: Reuse `SpotifyClient.search_track` behind a `search.py` helper
- **Rationale**: The backend already exposes `search_track(query)` which tries
  authenticated Spotify, then an anonymous Spotify token, then a 100% public iTunes
  Search API. Wrapping it in `search.py` (mirroring `preview.py`) lets the Swift app call
  it the same way it already calls preview/download, keeping the client agnostic.
- **Alternatives considered**: Hitting Spotify/iTunes directly from Swift (duplicates
  logic and auth handling already in the backend).

## Decision: Return `track_url` (Spotify URL) when available
- **Rationale**: On the Spotify-authenticated path `_parse_track` sets `spotify_id`,
  so `https://open.spotify.com/track/{id}` is a valid input for the existing
  `download.py`. The helper emits this so tapping a result can drive the normal download
  pipeline unchanged.
- **Alternatives considered**: Throwing the raw `TrackMetadata` at the resolver; the
  backend also resolves by title/artist via Odesli when no spotify_id exists (iTunes
  fallback), so that path still works losslessly in many cases.

## Decision: 8 results, artwork at ~600px
- **Rationale**: Matches existing preview artwork resolution; a compact grid/list keeps
  the UI lightweight.
- **Alternatives considered**: Single result (too rigid), artwork at full 1000px+ (heavier).

## Decision: Dedicated `SearchViewModel`
- **Rationale**: Keeps the search lifecycle separate from the existing
  `MainViewModel`; a tapped result hands the resolved URL back to the main flow via a
  callback/closures.
- **Alternatives considered**: Overloading `MainViewModel` (mixes concerns).