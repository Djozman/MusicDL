# Tasks: Download Activity UI with Track Selection

**Input**: Design documents from `/specs/002-download-activity-ui/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Desktop app**: `SwiftMusicDL/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new scaffolding needed — the Swift package already exists. Verify the
current sources and reconfirm the build script.

- [x] T001 [P] Verify existing Swift package builds cleanly with `swift build`
- [x] T002 [P] Re-run `./build_app.sh` to confirm the `.app` bundle assembles after changes

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend shared models and the backend service so both user stories can
consume per-track data and the adaptive-copy downloader. MUST complete before any UI work.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Create `ContentType` enum (`.single`, `.album`, `.playlist`) and `SelectableTrack` struct (title, artist, durationMS, selected) in `SwiftMusicDL/Models/TrackMetadata.swift`
- [x] T004 Extend `DownloadState.swift` with `.selectingTracks([SelectableTrack])` and `.downloading([TrackDownloadState])` cases; add `TrackDownloadState` struct (title, status: pending/downloading/completed/failed) in `SwiftMusicDL/Models/DownloadState.swift`
- [x] T005 Add `downloadSelectedTracks(_ tracks: [SelectableTrack], outputDir:)` to `BackendService` in `SwiftMusicDL/Services/BackendService.swift` that runs one `antra.json_cli --retry-track-json <payload>` per selected track using the full `TrackMetadata` payload and streams per-track events back to the caller

**Checkpoint**: Foundation ready — models expose content type, selectable tracks, and
per-track download states; backend service can download individual selected tracks.

---

## Phase 3: User Story 1 - Adaptive Downlading Download Status (Priority: P1) 🎯 MVP

**Goal**: Display adaptive status copy that distinguishes a single track from an
album/playlist with a live counter during downloads.

**Independent Test**: Download a single-track link and confirm status reads
`Downloading track <name> to ~/Music` (no counter). Then download an album/playlist link
and confirm status reads `Downloading track <current>/<total> (<name>) to ~/Music`, with
the counter updating live.

### Implementation for User Story 1

- [x] T006 [US1] Update `MainViewModel.confirmDownload()` in `SwiftMusicDL/ViewModels/MainViewModel.swift` to branch on content type and build a per-track `TrackDownloadState` list when starting a multi-track download
- [x] T007 [US1] Add a `downloadingText(for:)` helper in `SwiftMusicDL/ViewModels/MainViewModel.swift` that returns `Downloading track <name> to ~/Music` for single tracks and `Downloading track <current>/<total> (<name>) to ~/Music` for albums/playlists
- [x] T008 [US1] Update `ContentView.swift` to render the adaptive downloading text (using `downloadingText`) in the `.downloading` case in `SwiftMusicDL/Views/ContentView.swift`
- [x] T009 [US1] Stream per-track completion events from `BackendService.downloadSelectedTracks` and update the current-track index/name in `MainViewModel` in `SwiftMusicDL/ViewModels/MainViewModel.swift`

**Checkpoint**: At this point, User Story 1 delivers adaptive single-vs-multi download
status text that updates live. Independently testable.

---

## Phase 4: User Story 2 - Album/Playlist Track Selection & Per-Track Progress (Priority: P2)

**Goal**: When the user pastes an album/playlist link, show a selectable checklist before
downloading, and display a per-track progress bar for each selected track during download.

**Independent Test**: Paste an album/playlist link, verify a checklist of all tracks
appears with checkboxes, deselect some, confirm, and verify only selected tracks download
with each showing its own live progress bar.

### Implementation for User Story 2

- [x] T010 [P] [US2] Create `TrackSelectionView` with a toggle-able row per `SelectableTrack` (checkbox + name + artist) in `SwiftMusicDL/Views/TrackSelectionView.swift`
- [x] T011 [P] [US2] Create `TrackProgressBarView` that renders a single track's progress bar bound to a `TrackDownloadState` in `SwiftMusicDL/Views/TrackProgressBarView.swift`
- [x] T012 [US2] Update `MainViewModel` flow: on album/playlist preview, transition to `.selectingTracks` instead of straight to download in `SwiftMusicDL/ViewModels/MainViewModel.swift`
- [x] T013 [US2] Add `confirmSelection()` in `MainViewModel.swift` that collects only the selected tracks and starts `downloadSelectedTracks` in `SwiftMusicDL/ViewModels/MainViewModel.swift`
- [x] T014 [US2] Update `ContentView.swift` to render `TrackSelectionView` for the `.selectingTracks` state and a list of `TrackProgressBarView` rows for the `.downloading` state in `SwiftMusicDL/Views/ContentView.swift`

**Checkpoint**: At this point, User Stories 1 AND 2 both work — album/playlist links show a
checklist, only selected tracks download, and each gets a live progress bar; single tracks
keep the simple adaptive text.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Validation, docs, and final packaging.

- [x] T015 Rebuild and run `./build_app.sh` and launch `SwiftMusicDL.app`
- [x] T016 Run `specs/002-download-activity-ui/quickstart.md` validation scenarios end-to-end
- [x] T017 Update `SwiftMusicDL/README.md` with the adaptive status text and track-selection behavior

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verification only
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Story 1 (P1)**: Depends on Foundational
- **User Story 2 (P2)**: Depends on Foundational; builds on US1's downloading flow
- **Polish (Final Phase)**: Depends on US1 and US2

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on US2
- **User Story 2 (P2)**: Reuses US1's downloading infrastructure (`MainViewModel`,
  `BackendService.downloadSelectedTracks`)

### Within Each User Story

- Models before services; services before views; views bound to view-model before polish.

### Parallel Opportunities

- Phase 1 verification tasks are independent
- Foundational model tasks (T003, T004) can run before T005 (service) since T005 depends on them
- T010 and T011 (two new views) can run in parallel
- Several [P] tasks exist across setup and US2 views

---

## Parallel Example: User Story 2

```bash
# Launch both new views together:
Task: "Create TrackSelectionView in SwiftMusicDL/Views/TrackSelectionView.swift"
Task: "Create TrackProgressBarView in SwiftMusicDL/Views/TrackProgressBarView.swift"

# Then wire into the view-model sequentially:
Task: "Update MainViewModel flow for selection + confirmSelection"
Task: "Update ContentView for selectingTracks and downloading states"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 (foundational models + backend service)
2. Phase 3 (User Story 1): adaptive downloading status text
3. **STOP and VALIDATE**: single vs. multi counter copy works independently
4. Ship/demo if desired

### Incremental Delivery

1. Add User Story 2 (album/playlist checklist + per-track progress bars)
2. Polish: rebuild `.app`, run quickstart scenarios, update README

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to a specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
- Avoid: vague tasks, same-file conflicts, cross-story deps that break independence