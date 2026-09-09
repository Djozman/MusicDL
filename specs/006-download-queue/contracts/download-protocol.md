# Contract: Backend Download Invocation (queue integration)

## Overview

The Swift client (`BackendService`) drives the Python backend as a subprocess and
parses newline-delimited JSON from stdout. The existing `download.py` helper already
implements streaming per-track events. This contract documents the exact shape used
by the download-queue feature, plus the one explicit addition: an **output-directory
argument** so the user's per-session directory (not a hard-coded `~/Music`) is
honored.

## Invocation

Single release per subprocess invocation; the queue coordinator runs these
subprocesses in slots.

```
python3 download.py <source-url> [--out <output-dir>] [index index ...]
```

- `<source-url>` — the resolved track/album/playlist URL.
- `--out <output-dir>` — explicit per-session output directory (NEW; overrides
  `OUTPUT_DIR` env / `~/Music` default).
- `index ...` — optional 0-based indices of tracks to download within the release.
- Stderr may carry non-JSON diagnostics; stdout MUST be JSON-lines only.

## Stdout JSON-lines (consumed by the Swift client)

All lines are objects with a `type` field. The client parses them via
`BackendEvent`.

### `download_started`

Emitted once the release is resolved and the download is about to begin.

```json
{"type":"download_started","url":"<url>","total":<int>,"selected":[<int>,...]}
```

### `event` (per-track progress)

`name` is one of `track_started` / `track_completed` / `track_skipped` /
`track_failed`. `payload.track_index` is 1-based.

```json
{
  "type": "event",
  "name": "track_completed",
  "payload": {
    "track": "<title>",
    "artist": "<artist>",
    "track_index": <int>,
    "track_total": <int>,
    "message": "<status message>",
    "source": "<source id>",
    "error": "<failure detail, when failed>",
    "quality_label": "<label>",
    "attempt": <int>,
    "track_data": { }
  }
}
```

### `download_summary`

Emitted at the end of the release. Drives the entry to `done` (failed == 0) or
`failed` (failed > 0) and updates `downloadedCount`.

```json
{
  "type": "download_summary",
  "url": "<url>",
  "total": <int>,
  "downloaded": <int>,
  "failed": <int>,
  "skipped": <int>,
  "total_mb": <float>,
  "elapsed_seconds": <int>,
  "date": "<iso8601>"
}
```

### `done` / `error`

- `{"type":"done"}` — subprocess exited cleanly after summary.
- `{"type":"error","message":"...","url":"..."}` — top-level failure; exit code
  reflects failure when the process terminates abnormally.

## Mapping to queue states

| Backend signal | Queue effect |
|----------------|--------------|
| subprocess spawned for entry | entry → `active` |
| `track_completed` / `track_skipped` | increment entry `downloadedCount`; mark track done |
| `track_failed` | mark track failed for this entry |
| `download_summary` failed == 0 | entry → `done` |
| `download_summary` failed > 0 | entry → `failed` (retryable/removable) |
| interruption (app quit / signal) | in-progress entry → `paused` |
| retry of `paused`/`failed` | re-run subprocess from scratch (FR-017) |

## Output-directory rules

- Client passes the session `outputDirectory` as `--out` for every entry.
- When the user has not chosen a directory, the client uses and displays `~/Music`
  (FR-010).
- Backend MUST use the explicit `--out` value when provided; otherwise fall back to
  `OUTPUT_DIR` env, then `~/Music` (existing `resolve_out_dir` behavior in
  `antra_dl.py`).

## Test hooks

- Contract tests (pytest) MUST assert the JSON-line shapes above and the `--out`
  override behavior.
- Client queue tests (XCTest) MUST assert that `track_*` + `download_summary`
  events drive the documented state transitions.