# MusicDL

Small CLI tools built on top of the Antra pipeline.

## antra_dl.py — download from any supported service

Accepts a track/album/playlist URL from Spotify, Tidal, Amazon Music, Qobuz,
Deezer, Apple Music, SoundCloud, or YouTube Music, recognizes it, and downloads
the tracks as tagged lossless files.

```
python3 antra_dl.py --url "https://open.spotify.com/track/2xLMifQCjDGFmkHkpNLD9h"
python3 antra_dl.py --url "https://tidal.com/album/92967282"
python3 antra_dl.py --url "https://play.qobuz.com/album/1234" --format lossless-24
python3 antra_dl.py --url "https://music.amazon.com/albums/..." --out ~/Music -y
```

Options:
- `--out PATH` override output directory (default `~/Music`)
- `--format` output format (`source`, `flac`, `alac`, `mp3`, `lossless-24`, …)
- `-y` / `--yes` skip the confirmation prompt

## tidal_dl.py — quick download by Tidal track or album ID

```
python3 tidal_dl.py --id 119262125                      # track
python3 tidal_dl.py --id 92967282 --kind album          # album
```

## Requirements

Made for the repo root's `antra` package and runtime deps.

```
python3 -m pip install -r ../requirements-runtime.txt
```

ffmpeg should be on PATH for best results. Set `TIDAL_MIRROR_URL` /
`QOBUZ_MIRROR_URL` / `ANTRA_API_KEY` in `.env` or the endpoint manifest to enable
the 24-bit mirror sources (otherwise sources fall back to what's configured).

## Explicit / clean versions

Search results surface the explicit/clean status of each track when the provider
reports it. Search combines multiple sources and is sorted explicit-first:
- **Deezer** (public, no login) — returns the explicit flag and usually both the
  explicit and clean editions of a track, so the explicit version shows first.
- **Spotify** (when authenticated) — returns the native explicit flag.
- **iTunes / Apple** (public fallback).

If the store reports it, explicit variants are ordered first, followed by unknown,
then clean/non-explicit. Both the explicit and non-explicit editions remain separately
downloadable by tapping the matching row. When a provider does not expose the flag
the status is shown as "Unknown" rather than guessed.

## Search sources

The Mac frontend combines multiple search backends and merges/dedupes the results:
- **Spotify** — used first when authenticated (returns the explicit flag).
- **Deezer (public)** — used always, no login; exposes explicit editions.
- **Apple Music / iTunes (public)** — used as a broad fallback.

Downloading a Deezer search result requires configuring `DEEZER_ARL_TOKEN` (service.py
wires it to the Deezer download source); otherwise the explicit edition is still shown
and labeled, but a download may fall back to whatever source can resolve the track.

## UI

The macOS SwiftUI frontend follows the system light/dark appearance automatically and
uses a `NavigationSplitView` layout: the download queue lives in the sidebar, and the
search/paste flow (input bar, results, preview, track selection) fills the detail pane.
All view code lives in `SwiftMusicDL/Views/ContentView.swift`.

## Download queue & waitlist

The macOS app routes downloads through a per-session queue (`DownloadQueue` +
`QueueViewModel`) rather than downloading immediately:

- **Enqueue while downloading** — paste a link, confirm the resolved preview, and add
  it to the queue. New items wait in the waitlist as `pending` while another release
  downloads; when a slot frees, the next pending item starts automatically.
- **Observable states** — every entry shows `pending`, `active`, `done`, `failed`, or
  `paused` in the Queue panel, updated live without restarting.
- **Retry / remove** — failed or paused entries can be retried (re-downloaded from
  scratch) or removed from the queue.
- **Per-session output directory** — use the folder button in the Queue panel to choose
  where this session's downloads are saved (default `~/Music`), instead of a hard-coded
  location.
- **Per-session, not persisted** — the queue is kept in memory for the current session.
  On quit/interruption, in-progress items are marked `paused`; retrying re-downloads
  them from scratch (no partial-resume corruption). For an album/playlist, completed
  tracks are retained and only the in-progress and remaining tracks are re-downloaded.

The backend `download.py` helper accepts an explicit `--out <dir>` override (before or
after the URL), which the queue passes through to honor the chosen directory:# MusicDL
