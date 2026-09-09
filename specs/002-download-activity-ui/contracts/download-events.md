# Interface Contract: Download Activity Events

The Swift frontend reads the Python backend's stdout JSON-lines to drive the UI.
No backend changes are required; the contract below documents the events consumed.

## Backend Events Consumed (from `python3 -m antra.json_cli <url>`)

### `playlist_loaded` (metadata for album/playlist)
```json
{
  "type": "playlist_loaded",
  "title": "Album or Playlist Title",
  "artwork_url": "https://...",
  "content_type": "SINGLE|ALBUM|PLAYLIST",
  "track_count": 17,
  "tracks": [ { "artist": "A", "title": "Track Name", "duration_ms": 123 } ]
}
```

### `track_started` (per-track begin)
```json
{ "type": "event", "name": "track_started",
  "payload": { "track": "Name", "track_index": 1, "track_total": 17 } }
```

### `track_completed` / `track_failed` (per-track result)
```json
{ "type": "event", "name": "track_completed",
  "payload": { "track": "Name", "track_index": 1 } }
```

## Frontend Status Copy Contract
- **Single track**: `Downloading track <name> to <folder>`
- **Album/playlist**: `Downloading track <current>/<total> (<name>) to <folder>`
- `<folder>` is always `~/Music`.

## Selection Contract
- For album/playlist links: the frontend shows a checklist built from
  `playlist_loaded.tracks`; only the selected subset is sent to the downloader.