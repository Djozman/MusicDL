# Quickstart: Download Queue & Waitlist — Validation Guide

**Feature Spec**: [spec.md](spec.md) | **Data Model**: [data-model.md](data-model.md)
| **Contract**: [contracts/download-protocol.md](contracts/download-protocol.md)

This guide documents runnable validation scenarios that prove the feature works
end-to-end. It is a run/validation guide, not implementation code.

## Prerequisites

- macOS app built from `SwiftMusicDL` (or the app run from Xcode on a Mac).
- Backend repo at the app's configured `repoPath` (default `/Users/amm/MusicDL`)
  with `python3` and the `antra` package on `PYTHONPATH`.
- At least one supported service configured (e.g., a Tidal/Qobuz mirror or a
  working default source) so a real download can resolve.
- A couple of known good track/album URLs from a supported service for the tests below.

## Setup

1. Launch the app.
2. Confirm the default output directory shown is `~/Music` (FR-010). Note it in the
   UI without downloading yet.

## Scenario A — Enqueue while one is downloading (FR-001, FR-002, FR-003)

1. Paste a track URL → the resolved preview appears (FR-011/12/13).
2. Confirm "add to queue" → entry appears **pending** and begins downloading
   (**active**) since the queue is empty.
3. While it is downloading, paste a second (album) URL → confirm add → it is added
   to the waitlist as **pending**, does not interrupt the active download.
4. When the first release finishes (**done**), the second entry **automatically**
   begins downloading without user action.

**Pass if**: both entries complete with no user intervention after confirmation
(SC-001), and the queue never blocked the UI.

## Scenario B — Paste → fetch → confirm-add, nothing downloads early (FR-011/12/13)

1. Paste a URL but do NOT confirm.
2. Observe the resolved preview (title/artist, track count for albums/playlists).
3. **Pass if**: no download started before confirmation — the entry is only
   **pending** once confirmed, not **active**, unless it is the only item.

## Scenario C — Observable states, retry and remove (FR-004/005/007/008, SC-002/003)

1. Queue several releases. Confirm every entry shows a distinct state
   (pending/active/done/failed/paused) at a glance (SC-002).
2. Force a failure (e.g., an unresolvable track or drop the mirror URL) → the entry
   shows **failed**, and the rest of the queue continues (FR-015).
3. Retry the failed entry → it re-enters pending/active and downloads when the issue
   is fixed (FR-007, SC-003).
4. Remove a different failed/pending entry → it disappears from the queue (FR-008).

## Scenario D — Per-session output directory (FR-009/010, SC-005)

1. Choose a new output directory in the UI.
2. Download a track → confirm the file appears in the chosen directory, not `~/Music`.
3. Choose an invalid/inaccessible directory → a clear error is shown and the previous
   valid selection is kept (spec edge case).
4. The directory applies to downloads for the current session; selection is visible
   and changeable (SC-005).

## Scenario E — Pause and re-download on interruption (FR-016/017/018)

1. Start an album download and let a couple tracks complete.
2. Interrupt/quit mid-queue.
3. On reopening (same session), the in-progress entry is reflected as **paused**,
   not silently missing (FR-016).
4. Retry it → it re-downloads **from scratch** (FR-017); the album's already-completed
   tracks are retained and only the in-progress + remaining tracks re-download
   (FR-018).

## Scenario F — Edge cases

- Empty queue + single add starts immediately (spec edge case).
- Duplicate URL already queued → confirmation prompt, not silent re-add/reject.
- Queue at capacity → clear message; item not added.
- Album/playlist with many tracks → whole set queued as one entry (expands internally).
- Output directory becomes unavailable mid-session → graceful error.