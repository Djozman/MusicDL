# Download Activity UI

## User Story 1 - Track/Album/Playlist Download Status (Priority: P1)

**Goal**: Display a live, easily-readable download progress UI that adapts its status text based on whether the user is downloading a single track vs. an album/playlist.
- A single track shows: **Downloading track (name) to (folder)**
- An album/playlist shows: **Downloading track 1/17 (name) to (folder)**

**Rationale**: Users need clarity on how many tracks remain, the current item being processed, and the destination, to feel in control during long batch downloads.

## User Scenarios & Testing

### Scenario 1: Single Track Download (P1)
As a user, when I paste a single track link and confirm download, the UI must show a live progress indicator saying **"Downloading track (track name) to (folder)"** without a counter, since there is only one track.

**Acceptance Criteria**:
1. User pastes a single-track link (e.g., a Spotify/Tidal single track).
2. On download confirm, the status text reads `Downloading track <name> to <folder>`.
3. No track counter is shown for a single-track download.

### Scenario 2: Album / Playlist Download (P1)
As a user, when I paste an album/playlist link and confirm download, the UI must show a live progress indicator saying **"Downloading track 1/17 (name) to (folder)"**, where 1/17 is the current track out of the total tracks being downloaded.

**Acceptance Criteria**:
1. User pastes an album or playlist link (e.g., a Spotify/Tidal album or playlist with 17 tracks).
2. On download confirm, the status text reads `Downloading track <current>/<total> (<name>) to <folder>`.
3. The counter (current/total) and per-track name update live as each track is processed.

### Scenario 3: Destination Path Shown (P1)
As a user, I must always see the folder where the download is being saved so I know where my file(s) are being placed.

**Acceptance Criteria**:
1. Status text always includes the destination folder (e.g., `~/Music`).

## User Story 2 - Album/Playlist Track Selection Checklist (Priority: P2)

**Goal**: When the user pastes an album or playlist link, show a checklist of all tracks so they can choose which songs to download before starting.

**Rationale**: Users often only want specific songs from an album/playlist. A clear pre-download checklist gives them control and avoids unwanted downloads.

### Scenario 4: Track Selection Checklist (P2)
As a user, when I paste an album/playlist link, a checklist of all its tracks must appear, letting me select which ones to download.

**Acceptance Criteria**:
1. User pastes an album or playlist link (e.g., a Spotify/Tidal album or playlist).
2. A checklist appears showing every track (name, artist), each with a checkbox.
3. The user can toggle individual checkboxes on/off.
4. Only selected tracks are downloaded when the user confirms.

### Scenario 5: Per-Track Download Progress Bars (P2)
As a user, during a multi-track download, I must see an individual progress bar per selected track so I can tell which tracks are done, downloading, or pending.

**Acceptance Criteria**:
1. When a multi-track download starts, each selected track shows its own progress bar.
2. Each bar updates live and reflects that track's download state (pending → downloading → done/failed).
3. The overall counter (`Downloading track X/Y (name) to <folder>`) updates as tracks complete.

## Requirements

### Functional Requirements
- **FR1**: The app MUST determine whether the requested link is a single track (content_type `SINGLE` / no counter) or an album/playlist (multiple tracks) based on backend preview metadata.
- **FR2**: For single tracks, the UI MUST display `Downloading track <name> to <folder>`.
- **FR3**: For albums/playlists, the UI MUST display `Downloading track <current>/<total> (<name>) to <folder>`.
- **FR4**: The current track index and name MUST update live during multi-track downloads.
- **FR5**: The destination folder (`~/Music`) MUST always be displayed in the status text.
- **FR6**: The UI MUST show a progress indicator (spinner or progress bar) during downloads.
- **FR7**: For album/playlist links, the UI MUST display a checklist of all tracks, with a checkbox per track, before download starts.
- **FR8**: The user MUST be able to select/deselect individual tracks in the checklist.
- **FR9**: Only the user-selected tracks MUST be downloaded when confirming a multi-track download.
- **FR10**: During a multi-track download, the UI MUST show a per-track progress bar for each selected track showing pending/downloading/completed/failed states.

### Key Entities
- **DownloadRequest**: The URL the user pasted and the backend metadata.
- **TrackProgress**: Contains current track index, total track count, and track name.
- **ContentType**: Whether the request is a `SINGLE` track or a multi-track album/playlist.
- **SelectableTrack**: Contains track name, artist, and a boolean `selected` flag used in the album/playlist checklist.

## Success Criteria
- **Single-track**: Status text shows `Downloading track <name> to <folder>` and no counter.
- **Album/playlist**: Status text shows `Downloading track <current>/<total> (<name>) to <folder>`.
- Status text updates live with the current track being downloaded.
- Destination folder is always visible.
- An album/playlist link shows a pre-download checklist; only selected tracks are downloaded.
- Each selected track has its own live progress bar during download.

## Assumptions
- Destination folder is `~/Music` (default).
- Backend preview metadata provides enough info to determine content type and total tracks (from `playlist_loaded` events).
- The app streams backend JSON events to obtain per-track progress.
