# Data Model: Download Queue & Waitlist Management

**Date**: 2026-09-07
**Feature Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Entities

### QueueEntry

A single downloadable unit in the queue. For an album/playlist, the *release* is one
queue entry whose tracks are downloaded together by one backend subprocess (the
engine fans out internally). It is the unit shown in the waitlist UI.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Stable, unique identifier (e.g., persisted hash of the source URL). |
| `sourceUrl` | String | The pasted/resolved URL for this release (track/album/playlist). |
| `title` | String | Display title from the resolved preview. |
| `artist` | String? | Display artist from the resolved preview. |
| `contentType` | ContentType | `single` / `album` / `playlist` (existing enum). |
| `selectedIndices` | [Int] | Track indices to download within the release (all, or user's selection). |
| `totalTracks` | Int | Number of tracks being downloaded for this entry. |
| `downloadedCount` | Int | Completed tracks for this entry (for albums/playlists). |
| `exportedTrackStates` | [TrackDownloadState] | Per-track state mirror for progress/UI (reuses existing model). |
| `state` | QueueState | Overall entry state (see transitions). |
| `outputDirectory` | String | Session output directory bound when the entry starts. |

### DownloadQueue

The per-session, ordered collection of `QueueEntry` plus the concurrency/slot config.

| Field | Type | Description |
|-------|------|-------------|
| `entries` | [QueueEntry] | Ordered list; order defines promotion (FIFO among pending). |
| `activeSlots` | Int | Current number of active (downloading) subprocesses. |
| `maxConcurrent` | Int | Cap on active slots (default 1). |
| `capacity` | Int | Max number of entries (default to spec "reasonable"); 0 = unlimited. |
| `outputDirectory` | String | User-chosen per-session directory (default `~/Music`). |
| `sessionId` | String | Identifies this client session (not persisted). |

## State Machine

### QueueEntry.State (overall entry state)

```text
pending ──► active ──► done
   │          │
   │          ├──► failed ──► (retry) ──► pending/active
   │          │         └──► (remove)
   │          └──► paused ──► (retry) ──► active (re-download from scratch)
   │
   └──(remove)  at any pending state
```

| State | Meaning | Entry condition | Exit |
|-------|---------|-----------------|------|
| `pending` | Enqueued, not yet started, waiting in waitlist | Added to queue (FR-012/013); auto-advanced when a slot frees | → `active` when a slot is available (FR-003) |
| `active` | Backend subprocess running for this entry | Slot free and it's FIFO next; single item on empty queue starts immediately | → `done`, `failed`, or `paused` |
| `done` | All tracks completed/skipped | `download_summary` with 0 failures | terminal (removable; re-add for re-download) |
| `failed` | Some/all tracks failed but queue continues | completion with ≥1 failed tracks (FR-015) | → `pending`/`active` on retry (FR-007) or removed (FR-008) |
| `paused` | Interrupted (app quit / signal) while active | interruption of in-progress work (FR-016) | → `active` on retry, re-downloading from scratch (FR-017) |

### Invariants (validated by the client queue model)

- At most `maxConcurrent` entries are in `active` simultaneously (FR-002).
- A promotion to `active` only happens when a slot frees and the entry is the FIFO
  head among `pending`/`retry` (FR-003).
- Adding to the queue NEVER starts a download by itself unless the queue was empty
  and it becomes the only `pending`/`active` candidate (FR-013).
- A `failed` entry does not block other entries (FR-015): the failure is terminal
  for that entry until retry/remove, while pending entries continue to promote.
- Re-download always restarts from scratch (FR-017); per-entry `downloadedCount`
  resets on retry for the in-progress track, but for an interrupted album/playlist
  the completed tracks are retained and `totalTracks - retained` are re-downloaded
  (FR-018).

## Shape of Backend Contract (summary)

The queue model is driven by JSON-line events from the backend; see
[contracts/](contracts/) for the full contract.

- Backend invocation emits: `download_started`, per-track `event`
  (`track_started`/`track_completed`/`track_skipped`/`track_failed`),
  `download_summary`, `done`/`error`.
- Client maps `track_*` events → `exportedTrackStates` and recomputes the entry's
  overall `state`.
- `download_summary` (downloaded/failed/skipped counts) sets entry state to
  `done` or `failed`, and updates `downloadedCount` for progress display.