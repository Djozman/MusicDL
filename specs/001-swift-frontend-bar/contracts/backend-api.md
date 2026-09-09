# Interface Contract: Backend Integration

## Backend CLI / JSON Bridge Contract

### 1. Fetch Metadata
- **Command / Endpoint**: `python3 -m antra.json_cli inspect <url>`
- **Response Format (JSON)**:
  ```json
  {
    "success": true,
    "title": "Track Title",
    "artist": "Artist Name",
    "album": "Album Name",
    "artwork_url": "https://...",
    "source": "youtube"
  }
  ```

### 2. Download Track
- **Command / Endpoint**: `python3 -m antra.json_cli download <url> --output ~/Music`
- **Response Format (JSON)**:
  ```json
  {
    "success": true,
    "file_path": "/Users/amm/Music/Track Title.flac"
  }
  ```
