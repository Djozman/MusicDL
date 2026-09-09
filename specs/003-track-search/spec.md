# Track Search & Download

## User Story 1 - Search a Song and Download (Priority: P1)

**Goal**: Add a small search feature to the SwiftUI app so the user can type a song
query, see matching results, and tap one to download it via the existing backend
pipeline (Spotify/Tidal resolution → FLAC to `~/Music`).

**Rationale**: Users often know what they want by name rather than by a pasted URL. A
small search bar removes the need to find the link manually.

## User Scenarios & Testing

### Scenario 1: Search for a Track (P1)
As a user, I type a song title/artist into a search box and see a list of matching
tracks with their artwork, title, and artist.

**Acceptance Criteria**:
1. The app shows a search box.
2. Typing a query returns a list of matching tracks (artwork, title, artist).
3. Results appear without requiring a pasted URL.

### Scenario 2: Download a Search Result (P1)
As a user, I tap a search result and the track downloads to `~/Music` via the same
pipeline as pasting a link.

**Acceptance Criteria**:
1. Tapping a result starts the download.
2. The existing adaptive status text ("Downloading track <name> to ~/Music") is shown.
3. The resulting file lands in `~/Music`.

## Requirements

### Functional Requirements
- **FR1**: The app MUST provide a text input to search tracks by query.
- **FR2**: The app MUST display search results as a list showing artwork, track title, and artist.
- **FR3**: Tapping a search result MUST trigger a download of that track to `~/Music`.
- **FR4**: The download MUST reuse the existing backend pipeline (spotify/tidal resolution + download).
- **FR5**: The existing single-track adaptive download status text MUST be shown during the download.

## Success Criteria
- A user can find and download a known song within moments by name alone.
- Search results render with artwork and metadata.
- Downloads complete to `~/Music` using existing backend logic.

## Assumptions
- Search uses the backend's existing track-search (Spotify + public iTunes fallback).
- No local database; results come from the remote catalog.
- Search result tapping feeds the resolved track URL into the existing download flow.
