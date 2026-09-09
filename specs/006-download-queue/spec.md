# Feature Specification: Download Queue & Waitlist Management

**Feature Branch**: `006-download-queue`

**Created**: 2026-09-07

**Status**: Draft

**Input**: User description: "Download queue + waitlist — concurrent downloads, enqueue while another is downloading, observable pending/active/failed/done states, retry/remove of failed items. User-selectable download directory — per-session --out-style directory selection not hard-coded to ~/Music. Paste-link → fetch → confirm-add flow — paste a URL, resolve/fetch the track, then present a choice to add it to the download queue (rather than immediately starting)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Queue Downloads While One Is Running (Priority: P1)

A user downloads a track. While it is actively downloading, the user adds more
items (tracks, albums, playlists) to the queue. Each new item is enqueued into a
waitlist rather than interrupting or waiting for the active download and can be
seen pending its turn. The active download completes and the next pending item
automatically begins.

**Why this priority**: This is the core value of the feature — allowing multiple
items to be managed without blocking, which is the primary justification for a
queue at all.

**Independent Test**: The flow can be tested by starting one download, immediately
enqueuing a second, observing both listed, and confirming the second starts after
the first finishes.

**Acceptance Scenarios**:

1. **Given** an empty queue, **When** the user adds a first item and starts a download, **Then** the item transitions to an active/downloading state and the queue shows it as in-progress.
2. **Given** one item actively downloading, **When** the user enqueues a second item, **Then** the second item is added to the waitlist in a pending state, does not interrupt the active download, and is not shown as downloading.
3. **Given** an active download followed by a pending item, **When** the active download completes, **Then** the next pending item automatically begins downloading without user intervention.

---

### User Story 2 - Paste Link, Fetch, Then Confirm Add (Priority: P2)

A user pastes a URL (track, album, or playlist) into the app. The system fetches
and resolves the link, showing what the item is and which tracks it contains. The
user is then presented with a choice to add it to the download queue. Nothing is
downloaded until the user confirms.

**Why this priority**: This is the entry flow that feeds the queue and enforces the
"confirm before download" behavior, but it depends on the queue existing, so it is
second.

**Independent Test**: The flow can be tested by pasting a link, confirming the
resolved preview appears, choosing to add it, and verifying it lands in the queue
without having downloaded yet.

**Acceptance Scenarios**:

1. **Given** the paste-link input, **When** the user pastes a valid URL and presses submit, **Then** the system fetches and resolves the link and displays a preview of the item (title/artist, track count for albums/playlists).
2. **Given** a resolved preview is showing, **When** the user has the option to add it to the queue, **Then** the item is NOT downloaded until the user explicitly confirms adding it.
3. **Given** a resolved preview, **When** the user confirms adding it to the queue, **Then** the item is added to the queue in a pending state and no download starts automatically unless it is the only item.
4. **Given** an unresolved or unsupported URL, **When** the user submits it, **Then** the system shows a clear, structured error and offers to let the user correct or retry the link.

---

### User Story 3 - Observe Queue States and Handle Failures (Priority: P2)

A user views the full download queue, where every item shows a clear state:
pending, active/downloading, failed, done, or paused (for an interrupt). When an
item fails, the user can retry it or remove it from the queue. Completed items are
clearly distinguishable.

**Why this priority**: Making queue state observable and recoverable directly
supports reliability and the retry/remove behavior users need, but is built on the
queue core, so it follows the core queue story.

**Independent Test**: The flow can be tested by viewing the queue, triggering a
failure, and confirming the failed item can be retried or removed.

**Acceptance Scenarios**:

1. **Given** a populated queue, **When** the user views the queue, **Then** every item displays its current state (pending, active, failed, done, or paused) and the states are distinguishable at a glance.
2. **Given** an item whose download failed, **When** the user selects retry, **Then** the item re-enters the queue and is re-attempted.
3. **Given** a failed item, **When** the user selects remove, **Then** the item is removed from the queue and is no longer shown.
4. **Given** an in-progress item when the app is interrupted or closed, **When** the user returns, **Then** the item is shown as paused and is re-downloaded from scratch on retry rather than resumed.
5. **Given** any queue state change, **When** the queue updates, **Then** the user sees the updated state without restarting the app.

---

### User Story 4 - Choose the Download Directory Per Session (Priority: P3)

A user selects where downloaded files are saved for their current session, rather
than always defaulting to a hard-coded `~/Music` location. The chosen directory is
applied to downloads initiated during that session and is clearly visible to the
user.

**Why this priority**: This improves flexibility and is low-risk, but it is an
enhancement on top of the core queue flow, so it is the lowest priority of the
accepted stories.

**Independent Test**: The flow can be tested by choosing a directory, downloading an
item, and confirming the file appears in the chosen location.

**Acceptance Scenarios**:

1. **Given** the download settings, **When** the user selects an output directory, **Then** downloads for that session are saved to the selected directory.
2. **Given** a default is available, **When** the user does not choose a directory, **Then** the system uses the default location, which is shown to the user.
3. **Given** an invalid or inaccessible directory selection, **When** the user confirms it, **Then** the system shows a clear error and keeps the previous valid selection.

---

### Edge Cases

- What happens when the queue is empty and the user adds one item — does it start immediately?
- What happens when a paste-link resolves to an album or playlist with many tracks — is the whole set queued, or only the first track?
- How does the system handle duplicate items already in the queue — are they rejected or re-added?
- What happens to running/pending downloads when the app is closed or loses connectivity mid-download? (In-progress items show as paused; for an album/playlist, completed tracks are retained and in-progress/undownloaded tracks are re-downloaded on recovery.)
- What happens when a partially downloaded file is resumed — is it appended or re-downloaded? (Re-downloaded from scratch to avoid corruption.)
- What happens when two download attempts target the same item simultaneously?
- How does the system handle a failed item whose source has become permanently unavailable?
- What happens when the selected output directory becomes unavailable mid-session?
- What happens when a user tries to add more items than the waitlist is allowed to hold?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a download queue that can hold multiple items, each independently tracked.
- **FR-002**: System MUST allow enqueuing new items while another item is actively downloading, placing them into a waitlist without interrupting the active download.
- **FR-003**: System MUST automatically begin the next pending item when the active download completes.
- **FR-004**: System MUST expose the current state of every queue item, including at minimum: pending, active/downloading, failed, done, and paused (interrupted).
- **FR-005**: System MUST keep the observable queue state current (reflecting changes without requiring app restart).
- **FR-006**: System MUST allow the user to add a downloaded item again/duplicate handling MUST be defined (either explicit rejection or explicit confirmation of duplicates).
- **FR-007**: System MUST allow the user to retry items whose download failed.
- **FR-008**: System MUST allow the user to remove items from the queue, including failed items.
- **FR-009**: System MUST allow the user to select the output/download directory used for their current session.
- **FR-010**: System MUST use a selectable download directory rather than a hard-coded location; when no directory is chosen, MUST use and display a sensible default.
- **FR-011**: System MUST allow the user to paste a URL and trigger a fetch/resolve of the link before any download begins.
- **FR-012**: System MUST present the resolved item (with identifying details preview) and let the user confirm adding it to the queue before downloading.
- **FR-013**: System MUST NOT start a download from a paste-link until the user has confirmed adding it to the queue.
- **FR-014**: System MUST provide a clear, structured error message for unresolved or unsupported URLs.
- **FR-015**: System MUST handle failed downloads without blocking the rest of the queue, leaving the item retryable or removable.
- **FR-016**: System MUST treat the queue as per-session; when the app is closed or restarts mid-queue, any in-progress item MUST be reflected as paused (not silently missing), and the remaining queue state for that session is not transferred.
- **FR-017**: System MUST NOT resume a partially completed download by appending; a paused in-progress item MUST be re-downloaded from the start on recovery to avoid file corruption.
- **FR-018**: For an album/playlist with multiple tracks, when interrupting and later recovering, System MUST retain already-completed tracks and re-download only the in-progress track and any not-yet-downloaded tracks.

### Key Entities *(include if feature involves data)*

- **Queue Item**: A single downloadable unit (a track, or one track within an album/playlist) with attributes such as its source, identifying metadata (title, artist), its current state (pending/active/failed/done), and its resolved download location.
- **Download Queue**: An ordered collection of queue items representing what is waiting and what is in progress, with a defined capacity and ordering.
- **Download Session**: The current runtime context linking together the user-selected output directory, the queue of items, and the active download state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can enqueue at least one new item while another is actively downloading and have both complete successfully with no user intervention after confirmation.
- **SC-002**: 100% of queue items display a clear, correct state (pending, active, failed, or done) at all times.
- **SC-003**: A failed item can be retried and, when the underlying issue is resolved, successfully downloads without requeueing the whole queue.
- **SC-004**: Users can paste a link and reach a confirm-to-add prompt without any download having started; 100% of valid pasted links resolve to a preview.
- **SC-005**: The download directory is user-selectable and applied to all session downloads; users see and can change the current selection.

## Assumptions

- Users may queue tracks, albums, and playlists alike; an album/playlist expands into individual queue items when added.
- A single item added to an empty queue begins downloading immediately.
- The queue is per-session and is not persisted across app restarts; interrupted in-progress items surface as paused and are re-downloaded from scratch rather than resumed.
- For albums/playlists interrupted mid-queue, already-completed tracks are retained and only the in-progress plus not-yet-downloaded tracks are re-downloaded.
- The queue is bounded by a reasonable capacity to prevent runaway memory/disk usage; exceeded capacity is handled gracefully with a clear message.
- Existing download/source-resolution functionality will be reused for the actual fetching and downloading.
- The feature targets the existing desktop (macOS) app and CLI entry points; network connectivity is assumed for fetching and downloading.
- Duplicate queue items from repeated adds are confirmed with the user rather than silently rejected or duplicated.