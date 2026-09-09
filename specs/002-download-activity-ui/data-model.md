# Data Model: Download Activity UI

## Entities

### TrackPreview (existing model + new field)
- `title`: String?
- `artist`: String?
- `durationMS`: Int?

### SelectableTrack
- `title`: String?
- `artist`: String?
- `durationMS`: Int?
- `selected`: Bool (default true) — drives the album/playlist checklist

### ContentModel / TrackShape
- `contentType`: enum `.single` | `.album` | `.playlist`
- `title`: String
- `artworkURL`: String?
- `tracks`: [SelectableTrack] (empty for single)

### TrackDownloadState (per track)
- `title`: String?
- `status`: enum `.pending` | `.downloading` | `.completed` | `.failed(String)`

### DownloadStatus (existing enum extended)
- `idle`, `fetching`, `previewReady(TrackMetadata)`
- `selectingTracks([SelectableTrack])` — NEW: album/playlist checklist screen
- `downloading([TrackDownloadState])` — NEW: carries per-track states
- `completed`, `error(String)`

## State Transitions
`previewReady` → (if single) confirm → `downloading`
`previewReady` → (if album/playlist) → `selectingTracks` → confirm → `downloading(selected states)`
`downloading` → (per-track events update statuses) → all done → `completed`