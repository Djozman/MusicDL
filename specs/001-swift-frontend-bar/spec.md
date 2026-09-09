# Feature Specification: Lightweight Swift Frontend with Central Download Bar

## User Scenarios & Testing

### User Story 1: Paste Link and Preview Track (Priority: P1)
As a user, I want a clean, minimalist UI with a search/paste bar right in the middle of the screen, so that I can paste any music link (YouTube, Spotify, Apple Music, Qobuz, Deezer, etc.) and instantly see the album or track artwork/logo preview.

**Acceptance Scenarios**:
1. When the user opens the lightweight Swift application, a prominent text input bar is centered on the screen.
2. When the user pastes a supported music link into the bar, the application communicates with the backend, fetches track/album metadata, and displays the artwork/logo.
3. When the preview is displayed, the user is presented with a clear prompt asking if they want to download the track.

### User Story 2: One-Click Download to Default Music Directory (Priority: P1)
As a user, I want to confirm the download request so that the track is automatically downloaded and saved directly to `~/Music` (`users/amm/music`), with zero friction.

**Acceptance Scenarios**:
1. When the user confirms the download prompt, the application triggers the backend download process.
2. The downloaded audio file is saved in `~/Music` (`users/amm/music`), properly tagged and organized.
3. A success notification or status indicator shows that the download has completed.

---

## Requirements

### Functional Requirements

- **FR1**: The application MUST provide a minimalist graphical interface featuring a prominent input bar centered on the screen.
- **FR2**: The input bar MUST accept pasted URLs from any supported music source.
- **FR3**: Upon receiving a valid link, the application MUST query the backend to retrieve track/album metadata and artwork.
- **FR4**: The application MUST display the retrieved track/album artwork/logo visually to the user.
- **FR5**: The application MUST present a download confirmation prompt once the preview is successfully loaded.
- **FR6**: Upon user confirmation, the application MUST direct the backend to download the media file.
- **FR7**: The downloaded files MUST be stored in the local `~/Music` (`users/amm/music`) directory.

### Key Entities
- **Download Request**: Contains the source URL provided by the user.
- **Track Metadata**: Contains title, artist, album, and artwork/logo image URL.

---

## Success Criteria

### Quantitative Metrics
- Track metadata and preview artwork load within 3 seconds of pasting a valid link.
- Download confirmation and initiation occur with a single user click/tap.

### Qualitative Measures
- Interface is clean, lightweight, and focused entirely on the central paste bar and preview workflow.
- Seamless integration with the existing Python backend CLI/JSON capabilities.

---

## Assumptions & Constraints
- The Python backend is accessible locally or bundled to process requests and execute downloads.
- Default download path resolves to `~/Music`.
