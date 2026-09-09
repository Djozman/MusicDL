# Data Model: Lightweight Swift Frontend

## Entities

### DownloadRequest
- `url`: String (The user-provided music link)
- `timestamp`: Date

### TrackMetadata
- `title`: String
- `artist`: String
- `album`: String
- `artworkURL`: String?
- `source`: String

### DownloadState
- `status`: Enum (.idle, .fetching, .previewReady, .downloading, .completed, .error)
- `errorMessage`: String?
- `destinationPath`: String (Default: `~/Music`)
