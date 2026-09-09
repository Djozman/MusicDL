# Data Model: Track Search & Download

## Entities

### SearchResult
- `title`: String?
- `artist`: String?
- `album`: String?
- `artworkURL`: String?
- `trackURL`: String? — a resolvable Spotify track URL (when available) to feed download
- `source`: String?

### SearchQueryState
- `query`: String
- `results`: [SearchResult]
- `isLoading`: Bool
- `errorMessage`: String?

## State Transitions
`idle` → `searching(query)` → `results` | `error`
`results` → (tap) → hand `trackURL` to existing download flow → existing `DownloadStatus.*`
`error` → (retry) → `searching`