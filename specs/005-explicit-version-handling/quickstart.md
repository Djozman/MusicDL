# Quickstart: Verify Explicit Version Recognition & UI Revamp

This guide proves the feature works end-to-end. Implementation details live in
`tasks.md`; references to the contract and data model are linked below.

- Contract: [contracts/search-api.md](./contracts/search-api.md)
- Data model: [data-model.md](./data-model.md)
- Specification: [spec.md](./spec.md)

## P1 — Explicit / Non-explicit recognition & download (backend + contract)

### Prerequisites
- Python 3.10+ with the `antra` backend deps installed (see repo README).
- Either an authenticated Spotify token is configured, or the anonymous iTunes fallback
  is reachable. (The `is_explicit` field requires the Spotify-authenticated path, which
  reports `explicit` per track; the iTunes fallback returns `null`/absent.)

### Setup
```bash
cd /Users/amm/MusicDL
python3 -m pip install -r requirements-runtime.txt   # runtime deps
```

### Test the backend contract
```bash
python3 search.py "walk em down 21 savage mustafa"
```
**Expected**: at least one `search_results` JSON line whose `results` array contains
items with an `is_explicit` field (`true`, `false`, or absent). For a track with both
editions, explicit variants appear before non-explicit ones in the array.

```bash
python3 search.py "walk em down" | python3 -c "import json,sys; l=[x for x in sys.stdin if x.strip()]; r=json.loads(l[-1]).get('results',[det_fallback])..."
```
(A lightweight helper or manual inspection is fine; see contract for field names.)
Confirm: any result with `"title"` matching the query has `is_explicit` present, and
ordering puts `true` before `false`.

### Verify variant download selection (backend unit test)
Run the backend test for explicit propagation/ordering added in this feature:
```bash
python3 -m pytest tests/ -k explicit -q
```
**Expected**: tests pass, verifying (a) `is_explicit` is carried through `search_music()`/
`search.py` and (b) explicit results are ordered above non-explicit ones.

### Fetch a Tidal track ID from a selected search result (FR-007)
For any search row, resolve its Tidal ID so the 96 kHz explicit Tidal mirror is used:
```bash
python3 resolve_track.py "Walk Em Down" "Metro Boomin & 21 Savage" "https://www.deezer.com/track/2047662497"
```
**Expected**: a `{"type":"resolve", ...}` JSON line with either
- `"resolved": true` + `"url": "https://tidal.com/track/<id>"` (e.g. `263828941`), or
- `"resolved": false` + `"url": "<fallback_url>"` when the mirror has no match.

The returned URL then feeds the existing preview/download HiRes pipeline.

### Verify search↔paste-link parity (US3, FR-008/FR-009, SC-005)
Resolve the same song both ways and compare the delivered file specs:
```bash
# (a) Via a pasted Tidal link
python3 download.py "https://stage.tidal.com/track/263828941/u"
# (b) Via search → resolve_track (uses the first title+artist Tidal match, FR-010)
python3 search.py "walk em down 21 savage mustafa"
python3 resolve_track.py "Walk Em Down" "Metro Boomin & 21 Savage" "https://www.deezer.com/track/2047662497"
python3 download.py "$(last URL from resolve, e.g. https://tidal.com/track/263828941)"
```
**Expected**: the two downloads produce files with identical specs — sample rate 96 kHz,
codec FLAC (lossless), and explicit status — i.e. no 44.1 kHz MP3 fallback for the search
path (FR-009, SC-005). Confirm via `ffprobe` on both outputs:
```bash
ffprobe -v error -show_entries stream=codec_name,sample_rate -of csv=p=0 <file>
```

## P1 — Swift UI labeling & selection

### Prerequisites
- Xcode with SwiftUI; backend repo path configured in `BackendService`.

### Build & run
```bash
open SwiftMusicDL.xcodeproj   # per repo convention
```
Run the app (macOS target), then:
1. Type `walk em down 21 savage mustafa` in the search box and press Enter.
2. **Expected**: each result row shows an explicit/clean/unknown indicator; any explicit
   variant appears above the non-explicit one.
3. Click the explicit variant row. **Expected**: a download starts and the delivered
   track is the explicit version (SC-002).
4. Back out and click the non-explicit variant row. **Expected**: the clean version
   downloads (SC-002). No auto-selection occurs (FR-003).
5. Run the dedicated XCTest assertion for explicit-first ordering and indicator presence
   (added in this feature): `xcodebuild test ... -test-identifier <OrderingTest>`.

### Edge / negative cases (FR-005)
- On a query that only returns the iTunes fallback (no auth), confirm the indicator shows
  "Unknown" and the download still works. The UI must never mislabel a track as clean
  when the flag is absent.

## P2 — UI Revamp

### Visual acceptance
With the app running and switching the macOS system appearance (Light / Dark):
1. **Expected**: the app adapts (adaptive theming, FR-006) to both appearances without
   unreadable contrast or broken layout.
2. **Expected**: padding, typography hierarchy, and spacing are consistent and spacious
   across every state: idle, fetching/preview, track selection, downloading, completed,
   and error (SC-004).
3. **Expected**: a red error state, green success state, and the explicit/clean/unknown
   chips render correctly in both light and dark modes.

## Regression check (SC-004)
- Paste a URL (Spotify/Tidal/Qobuz/Amazon) in the top bar → preview → download still
  works.
- Search → select → download still works.
- A playlist/album still shows multi-track selection and per-track progress.