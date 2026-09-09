# Quickstart: Track Search & Download

## Prerequisites
- Existing antra backend + Python 3.14 with deps; project builds with `swift build`/`./build_app.sh`.

## Build & Run
1. `./build_app.sh`
2. Launch `SwiftMusicDL.app`.

## Validation Scenarios

### 1. Search a song
- In the search box, type e.g. `Drake Gods Plan`.
- The app shows a list of matching tracks with artwork, title, and artist.

### 2. Download from a result
- Tap a result.
- The app shows the single-track adaptive status: `Downloading track <name> to ~/Music`.
- Verify the resulting file lands in `~/Music`.

## Expected Outcome
- Names alone (no URL) are enough to find and download a known song, reusing the
  existing resolution pipeline. Contract: `contracts/search-api.md`.