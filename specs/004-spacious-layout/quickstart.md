# Quickstart: Spacious Layout & Navigation

## Prerequisites
- Project builds with `swift build` / `./build_app.sh`.

## Build & Run
1. `./build_app.sh`
2. Launch `SwiftMusicDL.app`.

## Validation Scenarios

### 1. Spacious header + fluid content
- Resize the window wide and narrow.
- The paste bar + search box stay in a top header; content spreads across width.

### 2. Content reflows on addition
- Type a search query and press Enter.
- Results appear in a results region below the header.
- Click a result → preview/download/selection panel appears below, smoothly reflowing
  without cramming into a narrow center column.

### 3. Clear navigation / hierarchy
- Confirm top: input + search. Below: results. Then: preview/selection/download progress.
- Loading/completion indicators stay in their own regions.

## Expected Outcome
- A spacious, multi-region window that uses available width and reflows content.
- Users can locate input, results, preview, and progress at a glance.