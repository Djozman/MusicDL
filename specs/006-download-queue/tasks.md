---

description: "Task list for Download Queue & Waitlist Management"

---

# Tasks: Download Queue & Waitlist Management

**Input**: Design documents from `/specs/006-download-queue/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: The constitution mandates test-driven verification (Principle III, NON-NEGOTIABLE),
so test tasks ARE included. Write them FIRST and confirm they fail before implementing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Swift client**: `SwiftMusicDL/` (Models, Services, ViewModels, Views)
- **Python backend**: repo root (`download.py`, `antra_dl.py`) and `antra/`
- **Tests**: `tests/SwiftMusicDLModels/` (XCTest), `tests/contract/` + `tests/unit/` (pytest)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Add `--out` argument handling to `download.py` (override `OUTPUT_DIR` env / `~/Music` default, mirroring `antra_dl.py:resolve_out_dir`)
- [X] T002 [P] Add a `--out`/output-dir parameter pass-through in `antra_dl.py` for programmatic reuse of `resolve_out_dir`
- [X] T003 Verify existing pytest (`tests/unit`, `tests/contract`) and XCTest (`tests/SwiftMusicDLModels`) harnesses run cleanly before new work

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core queue model, state machine, and backend protocol that EVERY user story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Create `QueueEntry` model in `SwiftMusicDL/Models/QueueEntry.swift` (fields per `data-model.md`: id, sourceUrl, title, artist, contentType, selectedIndices, totalTracks, downloadedCount, exportedTrackStates, state, outputDirectory)
- [X] T005 [P] Create `DownloadQueue` model in `SwiftMusicDL/Models/DownloadQueue.swift` (entries, activeSlots, maxConcurrent default 1, capacity, outputDirectory, sessionId)
- [X] T006 Create `QueueState` enum + state-transition logic in `SwiftMusicDL/Models/QueueEntry.swift` (pending→active→done/failed/paused; retry→active; remove; invariants per `data-model.md`)
- [X] T007 [P] Write XCTest for queue state machine + invariants in `tests/SwiftMusicDLModels/DownloadQueueTests.swift` (maxConcurrent cap, FIFO promotion, single-add-starts, stop-on-confirm) — must FAIL before T006 passes
- [X] T008 Write contract test for the JSON-line protocol + `--out` override in `tests/contract/test_queue_protocol.py` — must FAIL before T009
- [X] T009 Implement/extend the JSON-line protocol emitter for output-dir and summary in `download.py` per `contracts/download-protocol.md`
- [X] T010 [P] Extend `BackendService` to accept an explicit output directory argument (`SwiftMusicDL/Services/BackendService.swift`, `makeProcess`) and expose queue-aware subprocess spawning (one subprocess per queue entry)

**Checkpoint**: Foundation ready — queue model, state machine, and backend protocol exist and are tested. User story implementation can begin in parallel.

---

## Phase 3: User Story 1 - Queue Downloads While One Is Running (Priority: P1) 🎯 MVP

**Goal**: Enqueue items while one is actively downloading; waitlist them; auto-advance the next pending item when a slot frees.

**Independent Test**: Start a download, immediately enqueue a second item, observe both listed, and confirm the second starts automatically after the first finishes (Quickstart Scenario A).

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T011 [P] [US1] XCTest for enqueue-while-active + auto-advance in `tests/SwiftMusicDLModels/DownloadQueueTests.swift` (FR-002/FR-003)

### Implementation for User Story 1

- [X] T012 [P] [US1] Implement enqueue logic on `DownloadQueue` in `SwiftMusicDL/Models/DownloadQueue.swift` (adds pending entry, increments activeSlots when slot free) (depends on T004, T006)
- [X] T013 [US1] Implement slot promotion / auto-advance worker on `DownloadQueue` in `SwiftMusicDL/Models/DownloadQueue.swift` (promote FIFO pending → active when a slot frees) (depends on T012, T005)
- [X] T014 [US1] Implement subprocess orchestration to start a backend `download.py` process per active entry in `SwiftMusicDL/Services/BackendService.swift` (depends on T010)
- [X] T015 [US1] Create `QueueViewModel` in `SwiftMusicDL/ViewModels/QueueViewModel.swift` exposing `@Published` queue list + start/drive download tasks (depends on T013, T014)
- [X] T016 [US1] Emit entry state changes (pending/active→done/failed) and wire `download_summary` handling in `SwiftMusicDL/ViewModels/QueueViewModel.swift`
- [X] T017 [US1] Add a `QueueView` list in `SwiftMusicDL/Views/QueueView.swift` showing ordered entries + active/pending states, and add a queue panel to `SwiftMusicDL/Views/ContentView.swift`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (enqueue while active, auto-advance).

---

## Phase 4: User Story 2 - Paste Link, Fetch, Then Confirm Add (Priority: P2)

**Goal**: Paste a URL → fetch/resolve → show preview → user confirms adding it to the queue (nothing downloads before confirmation).

**Independent Test**: Paste a URL, confirm the resolved preview appears, choose to add it, and verify it lands in the queue without having downloaded (Quickstart Scenario B).

### Tests for User Story 2 ⚠️

- [X] T018 [P] [US2] XCTest for the confirm-add gating (no auto-download on add unless only item) in `tests/SwiftMusicDLModels/DownloadQueueTests.swift` (FR-013)

### Implementation for User Story 2

- [X] T019 [P] [US2] Wire the existing `BackendService.inspectLink` result into an "add-to-queue" confirmation state in `SwiftMusicDL/ViewModels/MainViewModel.swift` (submitURL → preview → queue add prompt) (depends on T005, T004)
- [X] T020 [US2] Implement "Confirm add to queue" action that enqueues the resolved entry instead of immediately downloading in `SwiftMusicDL/ViewModels/MainViewModel.swift`/`QueueViewModel.swift` (depends on T019, T012)
- [X] T021 [US2] Surface a structured error for unresolved/unsupported URLs (reuse FR-014) in `SwiftMusicDL/ViewModels/MainViewModel.swift` with option to correct/retry
- [X] T022 [US2] Handle album/playlist resolution → expansion into a single queue entry (whole set queued) in `SwiftMusicDL/ViewModels/MainViewModel.swift` (depends on T020)

**Checkpoint**: At this point, User Stories 1 AND 2 work independently (paste→confirm-add→queue).

---

## Phase 5: User Story 3 - Observe Queue States and Handle Failures (Priority: P2)

**Goal**: Every entry shows pending/active/done/failed/paused; failed items can be retried or removed; completion is detectable.

**Independent Test**: View a populated queue, trigger a failure, and confirm the failed item can be retried or removed (Quickstart Scenario C).

### Tests for User Story 3 ⚠️

- [X] T023 [P] [US3] XCTest for failed→retry/remove and paused→re-download-from-scratch transitions in `tests/SwiftMusicDLModels/DownloadQueueTests.swift` (FR-007/008/017)
- [X] T024 [P] [US3] Contract test asserting `download_summary` (failed>0) drives `failed` state, failed>0 does not block queue in `tests/contract/test_queue_protocol.py`

### Implementation for User Story 3

- [X] T025 [P] [US3] Implement retry action on `DownloadQueue` in `SwiftMusicDL/Models/DownloadQueue.swift` (failed/paused→pending/active via `.retry()`) (depends on T006)
- [X] T026 [US3] Implement remove action on `DownloadQueue` in `SwiftMusicDL/Models/DownloadQueue.swift` (any state, including failed) (depends on T006)
- [X] T027 [US3] Implement `paused` marking on interruption + re-download-from-scratch on retry in `SwiftMusicDL/Models/DownloadQueue.swift` (reset in-progress track, retain completed album tracks per FR-018), incl. `downloadSummary` failed>0→`failed` state mapping (depends on T025, T013)
- [X] T028 [US3] Surface all states (pending/active/done/failed/paused) distinctly and add retry/remove controls in `SwiftMusicDL/Views/QueueView.swift` + `SwiftMusicDL/ViewModels/QueueViewModel.swift` (depends on T017, T026, T025)

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 6: User Story 4 - Choose the Download Directory Per Session (Priority: P3)

**Goal**: User selects a session output directory (not hard-coded `~/Music`); applied to all session downloads; default shown; invalid choice handled.

**Independent Test**: Choose a directory, download, confirm the file appears there (Quickstart Scenario D).

### Tests for User Story 4 ⚠️

- [X] T029 [P] [US4] XCTest for output-directory selection + default + invalid-selection handling in `tests/SwiftMusicDLModels/DownloadQueueTests.swift` (FR-009/010)

### Implementation for User Story 4

- [X] T030 [P] [US4] Add per-session `outputDirectory` setter + default (`~/Music`) display on `DownloadQueue` in `SwiftMusicDL/Models/DownloadQueue.swift` (depends on T005)
- [X] T031 [US4] Pass the session directory as `--out`/`OUTPUT_DIR` to every backend subprocess in `SwiftMusicDL/Services/BackendService.swift` (depends on T001, T010)
- [X] T032 [US4] Add output-directory picker UI (with error on invalid/inaccessible selection keeping prior valid value) in `SwiftMusicDL/Views/ContentView.swift` + `SwiftMusicDL/ViewModels/QueueViewModel.swift` (depends on T030, T031)

**Checkpoint**: All four user stories are independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements affecting multiple user stories

- [X] T033 Handle duplicate existing queue URLs with a confirmation prompt (FR-006) in `SwiftMusicDL/Models/DownloadQueue.swift` + `SwiftMusicDL/ViewModels/QueueViewModel.swift`
- [X] T034 [P] Enforce bounded queue capacity with a clear message when full in `SwiftMusicDL/Models/DownloadQueue.swift` (spec edge case)
- [X] T035 Handle output directory becoming unavailable mid-session gracefully in `SwiftMusicDL/ViewModels/QueueViewModel.swift`
- [X] T036 [P] Add remove-at-any-state safety + duplicate-simultaneous-attempt guard in `SwiftMusicDL/Models/DownloadQueue.swift` (spec edge cases)
- [X] T037 Run `quickstart.md` validation scenarios A–F end-to-end and fix gaps
- [X] T038 Update README/docs with the queue, output-directory, and paste-confirm-add behavior

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can proceed sequentially in priority order (US1 → US2 → US3 → US4)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - no dependencies on other stories; represents the MVP
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - depends on core queue model (T005, T004) and enqueue (T012); feeds the queue from US1
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - depends on queue state machine (T006) and auto-advance (T013); layered on US1's queue
- **User Story 4 (P3)**: Can start after Foundational (Phase 2) - depends on `BackendService` output-dir wiring (T010/T031); independent of US1-3 internals

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before UI/view integration
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1 Setup tasks T001 and T002 can run in parallel ([P])
- Phase 2 Foundational: T005, T007, T008, T010 can run in parallel ([P])
- Tests within each user story marked [P] can run in parallel
- User stories can be worked on in parallel once Foundational completes (if capacity allows)
- Polish tasks T034/T036 and T033/T035 differ in scope

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "XCTest for enqueue-while-active + auto-advance in tests/SwiftMusicDLModels/DownloadQueueTests.swift"

# Launch parallelizable models/components together:
Task: "Implement enqueue logic on DownloadQueue in SwiftMusicDL/Models/DownloadQueue.swift"
Task: "Implement subprocess orchestration in SwiftMusicDL/Services/BackendService.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T010)
3. Complete Phase 3: User Story 1 (T011-T017)
4. **STOP and VALIDATE**: Test User Story 1 independently (Quickstart Scenario A)
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP: queued concurrent downloads)
3. Add User Story 2 → Test independently (paste→confirm-add feeds the queue)
4. Add User Story 3 → Test independently (observable state + retry/remove + paused)
5. Add User Story 4 → Test independently (per-session output directory)

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core queue/auto-advance)
   - Developer B: User Story 2 (paste/confirm-add flow)
   - Developer C: User Story 4 (output-directory, largely independent)
3. Developer D layers User Story 3 (state observability + retry/remove) on US1's queue afterwards

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (constitution Principle III)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence