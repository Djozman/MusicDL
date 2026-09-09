# Interface Contract: Explicit-Version-Aware Track Search

The Swift frontend calls the `search.py` backend helper over the existing JSON line
protocol. This contract extends the original search contract
(`specs/003-track-search/contracts/search-api.md`) with an `is_explicit` field on each
result. The change is purely additive; both backend can emit the field and the frontend
handles its absence as "unknown".

## `search.py <query>`

### Success (`type: "search_results"`)
```json
{
  "type": "search_results",
  "query": "walk em down 21 savage mustafa",
  "results": [
    {
      "type": "track",
      "title": "Walk Em Down (Explicit)",
      "artist": "21 Savage, Mustafa, Metro Boomin",
      "album": "SAVAGE MODE II",
      "subtitle": "",
      "artwork_url": "https://...600x600bb.jpg",
      "track_url": "https://open.spotify.com/track/AAAexplicitId",
      "source": "spotify",
      "is_explicit": true
    },
    {
      "type": "track",
      "title": "Walk Em Down",
      "artist": "21 Savage, Mustafa, Metro Boomin",
      "album": "SAVAGE MODE II",
      "artwork_url": "https://...600x600bb.jpg",
      "track_url": "https://open.spotify.com/track/BBBcleanId",
      "source": "spotify",
      "is_explicit": false
    }
  ]
}
```

### Ordering contract
Within results for a single track/album family, the backend MUST emit explicit variants
(`is_explicit: true`) before non-explicit variants (`is_explicit: false`). Unknown
(`null`/absent) sorts between them. This implements FR-002a.

### Frontend handling of `is_explicit`
- `true` → render an **Explicit** indicator.
- `false` → render a **Clean / Non-explicit** indicator.
- `null` / absent / decode failure → render an **Unknown** indicator (FR-005); never
  guess explicit vs. clean.

### Error (`type: "error"`)
```json
{ "type": "error", "message": "No results found" }
```

### Frontend flow
- User types a query → app calls `search.py <query>`.
- On result, the app renders each row's artwork/title/artist plus the explicit/clean/
  unknown indicator in `SearchResultsView`, ordered by `is_explicit` (explicit first).
- On tap of a variant row, the app asks the backend to resolve a Tidal track ID
  (`resolve_track.py <title> <artist> <track_url>`), then downloads that Tidal ID via
  the HiRes pipeline. No auto-selection (FR-003); the user chooses the variant.
- The existing single-track adaptive status text and `download.py` pipeline are reused.

## `resolve_track.py <title> <artist> [fallback_url]` (NEW, FR-007)

Upgrades a selected search result to a Downloadable Tidal ID so the HiRes Tidal source
(96 kHz explicit) is used, matching a directly-pasted Tidal link.

### Success — Tidal ID found
```json
{
  "type": "resolve",
  "title": "Walk Em Down",
  "artist": "Metro Boomin & 21 Savage",
  "url": "https://tidal.com/track/263828941",
  "source": "tidal",
  "resolved": true
}
```

### Success — no Tidal ID (fallback to original URL)
```json
{
  "type": "resolve",
  "title": "Walk Em Down",
  "artist": "Metro Boomin & 21 Savage",
  "url": "https://www.deezer.com/track/2047662497",
  "source": "",
  "resolved": false
}
```

### Error
```json
{ "type": "error", "message": "Resolve failed: <reason>" }
```

### Resolution logic
- `resolve_track.py` runs `TidalMirrorAdapter.search()` against the configured Tidal
  mirror (endpoint manifest) using title/artist and returns the *first* (top-ranked) match
  as `https://tidal.com/track/<id>` — **no confirmation step** (FR-010). This ensures the
  search result resolves to the same Tidal ID a pasted link would.
- If the mirror returns no match, `resolved: false` is returned and the frontend falls
  back to the search result's original `track_url`.
- The resulting URL feeds the existing `preview.py` / `download.py` HiRes pipeline.

### Quality parity (FR-008, FR-009, SC-005)
Because a search selection resolves to the same Tidal track ID (FR-007/FR-010) and routes
through the same HiRes pipeline as a pasted link, the delivered file MUST match the
pasted-link download in sample rate (96 kHz), codec (FLAC), and explicit status. There is
no separate lower-quality (44.1 kHz MP3) fallback path for search results.

## `download.py` (unchanged)
No contract change. Given a Tidal track URL, the resolver routes to the Tidal HiRes
mirror/hifi source, preserving the explicit/clean choice end-to-end.