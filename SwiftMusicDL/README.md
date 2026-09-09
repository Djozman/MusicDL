# SwiftMusicDL

A lightweight native macOS SwiftUI frontend for the MusicDL Python backend (`antra`), featuring a prominent centered search/paste bar for any music link, instant artwork/metadata preview, and frictionless one-click downloads directly to `~/Music`.

## Requirements
- macOS 13.0+
- Xcode 15+ / Swift 5.9+
- Python 3.10+ with `antra` backend installed.

## Usage
1. Open the project or build with Swift Package Manager / Xcode.
2. Paste any music link (Spotify, YouTube, Apple Music, Qobuz, Deezer, etc.) into the centered bar.
3. Review the fetched track artwork and metadata.
4. Click download to save the track directly into `~/Music`.

## Search
Use the search box to find a song by name (Spotify + iTunes catalog). Tap a result to
download it via the same pipeline — no need to hunt for a URL.

## Download activity
- **Single track**: status shows `Downloading track <name> to ~/Music`.
- **Album/playlist**: a checklist of all tracks appears — tick only the ones you want —
  and status shows `Downloading track <current>/<total> (<name>) to ~/Music` with a
  per-track progress bar for each selected track.

## Build
Assemble the `.app` bundle (including the icon) with `./build_app.sh`.
