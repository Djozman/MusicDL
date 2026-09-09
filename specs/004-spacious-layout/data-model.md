# Data Model: Spacious Layout & Navigation

No new persistent entities — this is a presentational change to the SwiftUI view
hierarchy. The existing state-driven `DownloadStatus` enum and `SearchViewModel`
continue to drive rendering; the layout simply reorganizes how those states are shown.

## Layout Regions (view-level, not data)
- **Header region**: paste/URL input + Inspect button + search box.
- **Results region**: rendered when `SearchViewModel` has results (reflows, scrollable).
- **Content region**: rendered from `viewModel.status`:
  - `.fetching` → loading indicator
  - `.previewReady` → preview card
  - `.selectingTracks` → track selection checklist
  - `.downloading` → download progress panel
  - `.completed` → completion screen
  - `.error` → error screen
- Regions stack top-to-bottom with consistent spacing; content reflows as regions appear.