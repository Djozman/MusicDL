# Quickstart: Download Activity UI with Track Selection

## Prerequisites
- Existing antra Python backend at repo root (runnable via `python3 -m antra.json_cli`).
- Python 3.14 with backend deps (`/Library/Frameworks/Python.framework/Versions/3.14/bin/python3`).
- Swift 5.9+ / Xcode; project builds with `swift build`.

## Build & Run
1. Build the frontend:
   ```sh
   ./build_app.sh
   ```
2. Launch `SwiftMusicDL.app`.

## Validation Scenarios

### 1. Single track — adaptive copy
- Paste a single-track link (e.g. `https://tidal.com/track/217570536/u`).
- Preview artwork appears; confirm download.
- Verify status reads `Downloading track <name> to ~/Music` (no counter).

### 2. Album/playlist — checklist + counter
- Paste an album or playlist link.
- Verify a checklist of all tracks appears with checkboxes.
- Deselect a couple tracks; confirm.
- Verify status reads `Downloading track <current>/<total> (<name>) to ~/Music` and that
  only the selected tracks were downloaded.

### 3. Per-track bars
- During a multi-track download, verify each selected track shows its own progress bar
  and that bars flip pending → downloading → completed/failed live.

## Expected Outcome
- Destination files land in `~/Music` (see `contracts/download-events.md` for the event
  stream contract the UI consumes).