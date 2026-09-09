---

description: "Task list template for feature implementation"
---

# Tasks: Explicit Version Recognition & UI Revamp

**Input**: Design documents from `specs/005-explicit-version-handling/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/search-api.md

**Tests**: The constitution (Principle III, Test-Driven Verification) makes automated tests NON-NEGOTIABLE, so test tasks are included and written BEFORE implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project + app**: Python backend files at repo root (`search.py`, `antra/`); SwiftUI frontend under `SwiftMusicDL/`; backend tests under `tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 [P] Verify backend test runnable: `python3 -m pytest tests/ -q` executes existing suite cleanly at repo root
- [x] T002 [P] Verify SwiftUI app builds for the current feature module with `xcodebuild build` (macOS target) in `SwiftMusicDL/`
- [x] T003 [P] Confirm `search.py <query>` returns `search_results` JSON and note the current result shape for regression comparison

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core pieces that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Add `is_explicit` field to the `SearchResult` Swift model in `SwiftMusicDL/Models/SearchResult.swift`, decoding `is_explicit` as `Bool?` (nullable; `null` = unknown per FR-005) and mapping it to an `ExplicitStatus` enum (`explicit`/`clean`/`unknown`)
- [x] T005 [P] Add `isExplicit` passthrough to `SwiftMusicDL/Models/TrackMetadata.swift` decoding `is_explicit: Bool?` from the preview payload (supports exposing explicitness on the preview card)
- [x] T006 Add backend helper to compute stable explicit-first ordering shared by tests and `search.py` in `antra/utils/search_ordering.py` (filters: `is_explicit == true` top, `null` middle, `false` bottom), implementing FR-002a

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Explicit / Non-explicit Recognition & Download (Priority: P1) 🎯 MVP

**Goal**: Users get distinct, correctly-labeled explicit/clean search results that are each independently downloadable, with explicit variants ordered first (FR-001..FR-005, SC-001..SC-003).

**Independent Test**: `python3 search.py "walk em down 21 savage mustafa"` emits an `is_explicit` field per result with explicit variants before non-explicit ones; a pytest test asserts propagation + ordering, and the Swift UI renders Explicit/Clean/Unknown indicators and downloads the selected variant.

### Tests for User Story 1 (write these FIRST, ensure they FAIL before implementation) ⚠️

- [x] T007 [P] [US1] Contract test asserting `search.py` results carry `is_explicit` (true/false/absent) and explicit variants precede non-explicit ones in `tests/contract/test_search_explicit.py`
- [x] T008 [P] [US1] Unit test for explicit-first ordering helper covering true/null/false groups in `tests/unit/test_search_ordering.py` (depends on T006)

### Implementation for User Story 1

- [x] T009 [US1] Extend `search_music()` in `antra/core/spotify.py` to include `is_explicit` on Spotify track results (`it.get("explicit")`, None when unknown), and emit clean/edited variants distinctly rather than dropping them (depends on T004/T007 conceptual contract)
- [x] T010 [US1] Apply explicit-first ordering to the `results` list in `search.py` using the helper from T006 before emitting `search_results` (depends on T006, T009)
- [x] T011 [US1] Ensure `BackendService.searchTracks` at `SwiftMusicDL/Services/BackendService.swift` decodes the new `is_explicit` key into `SearchResult` (no transport change; verified by existing decode path after T004)
- [x] T012 [US1] Render the explicit/clean/unknown indicator on each result row in `SwiftMusicDL/Views/SearchResultsView.swift`, ordered explicit-first (visual grouping), keeping `track_url` the tap target for the download flow (depends on T004)
- [x] T013 [US1] Wire variant selection end-to-end: a tapped result row feeds its `track_url` into the existing `submitURL()`/download pipeline with no auto-selection in `SwiftMusicDL/Views/ContentView.swift` (depends on T012)
- [x] T014 [US1] Add error/edge handling: when `is_explicit` is absent, decode defaults to unknown and the UI shows "Unknown" (never "Clean") in `SwiftMusicDL/Views/SearchResultsView.swift` (depends on T004)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Revamp the Whole User Interface (Priority: P2)

**Goal**: A spacious, modern, consistent visual redesign that adapts to the system light/dark appearance, with no regression in existing flows (FR-006, SC-004).

**Independent Test**: App runs under both macOS Light and Dark appearances with consistent, readable spacing and typography across all states (idle, preview, selection, downloading, completed, error); all existing flows still work; XCTest asserts indicator presence.

### Tests for User Story 2 (write these FIRST, ensure they FAIL before implementation) ⚠️

- [x] T015 [P] [US2] XCTest asserting search results render an Explicit/Clean/Unknown indicator and explicit rows order above clean rows in `SwiftMusicDL/Tests/SearchExplicitOrderingTests.swift` (depends on T012)

### Implementation for User Story 2

- [x] T016 [P] [US2] Introduce a shared, adaptive design system (spacing scale, typography, semantic colors using system light/dark dynamic colors) in `SwiftMusicDL/Views/DesignSystem.swift`, replacing hard-coded colors with adaptive equivalents
- [x] T017 [P] [US2] Rework layout/spacing of the header and status region in `SwiftMusicDL/Views/ContentView.swift` using the design system, preserving all states (depends on T013)
- [x] T018 [P] [US2] Refresh `SwiftMusicDL/Views/SearchResultsView.swift` row styling with the design system, keeping the explicit indicator (depends on T016, T012)
- [x] T019 [P] [US2] Refine preview and track-selection surfaces with the design system in `SwiftMusicDL/Views/PreviewCardView.swift` and `SwiftMusicDL/Views/TrackSelectionView.swift`
- [x] T020 [US2] Restyle download progress and state views (downloading/completed/error) with the design system in `SwiftMusicDL/Views/ContentView.swift` (DownloadingView) and `SwiftMusicDL/Views/TrackProgressBarView.swift`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Search Must Deliver the Same Track as a Pasted Link (Priority: P1) 🎯 MVP

**Goal**: A searched track downloads the same 96 kHz explicit FLAC as its pasted Tidal link, with no lower-quality (44.1 kHz MP3) fallback (FR-007, FR-008, FR-009, FR-010, SC-005). Realizes the reported bug fix for "Walk Em Down".

**Independent Test**: `python3 search.py "walk em down 21 savage mustafa"` → `python3 resolve_track.py "Walk Em Down" "Metro Boomin & 21 Savage" <url>` returns the Tidal ID `263828941` (first-title+artist match, no confirmation). Downloading that ID and downloading the pasted link `https://stage.tidal.com/track/263828941/u` produce files with identical specs (96 kHz FLAC, explicit) via `ffprobe`.

### Tests for User Story 3 (write these FIRST, ensure they FAIL before implementation) ⚠️

- [ ] T024 [P] [US3] Contract test asserting `resolve_track.py <title> <artist> <url>` emits `{"type":"resolve", "resolved": true/false, ...}` with `resolved: true` returning `https://tidal.com/track/<id>` in `tests/contract/test_resolve_track.py`
- [ ] T025 [P] [US3] Unit test asserting the resolver returns the FIRST title+artist match from `TidalMirrorAdapter.search()` with no confirmation step (FR-010) in `tests/unit/test_resolve_track.py`
- [ ] T026 [P] [US3] Parity test: for a track resolvable via Tidal, asserting the search-selected resolution produces the same Tidal track ID as the direct link and the same output file specs (sample rate 96 kHz, codec FLAC, explicit) in `tests/contract/test_search_tidal_parity.py` (SC-005)

### Implementation for User Story 3

- [ ] T027 [US3] Create `resolve_track.py` at repo root (new helper) implementing FR-007: run `TidalMirrorAdapter.search()` against the configured Tidal mirror (endpoint manifest) using title/artist, return the first match as `https://tidal.com/track/<id>` with `resolved: true`, or `resolved: false` + original `track_url` fallback when no match (depends on T024/T025)
- [ ] T028 [US3] Wire the no-confirmation first-match rule (FR-010) into `resolve_track.py`: take the top-ranked exact title+artist result returned by `TidalMirrorAdapter.search()` with no confirmation prompt (depends on T027)
- [ ] T029 [US3] Route a selected search result through `resolve_track.py` before download in `SwiftMusicDL/Services/BackendService.swift` (`submitURL`/download path), so the search selection resolves to a Tidal ID and downloads via the same HiRes pipeline as a pasted link (depends on T027)
- [ ] T030 [US3] Ensure no 44.1 kHz MP3 fallback for search paths: verify `download.py` routes the resolved Tidal URL to the HiRes (mirror/hifi) source and remove/disable any lower-bitrate fallback used for search results (FR-008, FR-009) in `search.py` / `SwiftMusicDL/Services/BackendService.swift`

**Checkpoint**: User Stories 1, 2 AND 3 should each work independently; search matches paste-link quality

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T031 [P] Run quickstart.md validation including the search↔paste-link parity scenario (US3/SC-005) and US1 contract check at `specs/005-explicit-version-handling/quickstart.md`
- [x] T022 [P] Add regression note + README mention of explicit/clean variant support in `README.md`
- [x] T023 Run the full backend suite `python3 -m pytest tests/ -q` and the SwiftUI tests to confirm no regressions (SC-004)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 (P1) first, since US2's indicator test depends on US1's labeling (T012)
  - US2 can align after US1 but is largely independent (different view files)
  - US3 (P1) is largely independent of US1/US2 (touches `resolve_track.py`, backend
    download routing) and can proceed in parallel once Foundational is complete
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2). Its `track_url`→download integration (T013) requires US1's indicator work (T012).
- **User Story 2 (P2)**: Can start after Foundational; the ordering/indicator XCTest (T015) depends on US1 (T012). Design-system tasks (T016-T020) are otherwise independent, touching distinct view files.
- **User Story 3 (P1)**: Can start after Foundational; all tasks (T024-T030) are self-contained around `resolve_track.py` + backend download routing and depend only on each other (T024/T025 before T027; T027 before T028-T030).

### Within Each User Story

- Tests MUST be written and FAIL before implementation (T007/T008 precede T009-T014; T015 precedes T016-T020; T024-T026 precede T027-T030)
- Backend propagation/ordering (T009, T010) before frontend decode (T012)
- Design system (T016) before view rewrites that consume it (T017-T020)
- US3: `resolve_track.py` helper (T027) and first-match rule (T028) before frontend routing (T029)

### Parallel Opportunities

- Phase 1 tasks T001-T003 run in parallel
- Phase 2 tasks T004, T005, T006 run in parallel (distinct files)
- T007 and T008 run in parallel
- US2 design-system tasks T016-T020 run in parallel (distinct view files)
- US3 tasks T024, T025, T026 run in parallel (distinct test files)
- T021, T022 run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test asserting search.py results carry is_explicit in tests/contract/test_search_explicit.py"
Task: "Unit test for explicit-first ordering helper in tests/unit/test_search_ordering.py"

# Launch ordering/backend work together:
Task: "Extend search_music() to include is_explicit in antra/core/spotify.py"
Task: "Apply explicit-first ordering in search.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently (SC-001..SC-003)
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (explicit recognition + download) → Test independently → Deploy/Demo (MVP!)
3. Add User Story 3 (search↔paste-link parity bug fix) → Test independently → Deploy/Demo
4. Add User Story 2 (UI revamp) → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (backend + search + UI labeling)
   - Developer B: User Story 3 (resolve_track.py + Tidal parity bug fix)
   - Developer C: User Story 2 design system + view restyling (referencing US1's indicator)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (per Test-Driven Verification principle)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence