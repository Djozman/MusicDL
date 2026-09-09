# Tasks: Track Search & Download

**Input**: Design documents from `/specs/003-track-search/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- **Backend helper**: repository root
- **Desktop app**: `SwiftMusicDL/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new scaffolding needed — confirm the existing build pipeline still works.

- [x] T001 [P] Verify the existing Swift package builds cleanly with `swift build`
- [x] T002 [P] Confirm `./build_app.sh` assembles and signs the `.app`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the backend search helper and a Swift `SearchResult` model so the UI
story can consume results. MUST complete before any UI work.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Add `SearchResult` struct (title, artist, album, artworkURL, trackURL, source) as a Codable model in `SwiftMusicDL/Models/SearchResult.swift`
- [x] T004 Create `search.py` backend helper at repo root that queries the antra backend's track search (multi-result) and emits a single JSON line `{"type":"search_results","query":...,"results":[{...}]}`
- [x] T005 Add `searchTracks(_ query: String)` to `BackendService` in `SwiftMusicDL/Services/BackendService.swift` that runs `search.py <query>` and decodes the results array into `[SearchResult]`

**Checkpoint**: Foundation ready — `search.py` returns JSON results and `BackendService`
exposes a typed `searchTracks` method.

---

## Phase 3: User Story 1 - Search a Song and Download (Priority: P1) 🎯 MVP

**Goal**: Add a small search box to the app; typing a query shows matching tracks
(artwork, title, artist); tapping a result downloads it via the existing pipeline to `~/Music`.

**Independent Test**: Type "Drake Gods Plan", confirm a results list renders with
artwork/title/artist, tap a result, and confirm the single-track adaptive status
("Downloading track <name> to ~/Music") shows and the file lands in `~/Music`.

### Implementation for User Story 1

- [x] T006 [P] [US1] Create `SearchViewModel` (query, results, isLoading, error; `search()`, `resultSelected(_ result:)` returning trackURL) in `SwiftMusicDL/ViewModels/SearchViewModel.swift`
- [x] T007 [P] [US1] Create `SearchResultsView` that renders a search box + list of results (artwork via AsyncImage, title, artist) with a tap handler in `SwiftMusicDL/Views/SearchResultsView.swift`
- [x] T008 [US1] Wire `SearchResultsView` into `ContentView` (e.g. below the paste bar) with a callback that sets `viewModel.inputURL` to the selected result's `trackURL` and calls the existing `submitURL()` + download flow in `SwiftMusicDL/Views/ContentView.swift`
- [x] T009 [US1] Ensure a tapped search result flows into the existing single-track adaptive download status (no code change expected; verify `MainViewModel.downloadingText` renders correctly) in `SwiftMusicDL/ViewModels/MainViewModel.swift`

**Checkpoint**: At this point, User Story 1 is fully functional — search works and a
tapped result downloads to `~/Music` via the existing pipeline.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Validation, docs, and final packaging.

- [x] T010 Rebuild and run `./build_app.sh`, then launch `SwiftMusicDL.app`
- [x] T011 Run `specs/003-track-search/quickstart.md` validation scenarios end-to-end
- [x] T012 Update `SwiftMusicDL/README.md` with the search feature

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verification only
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS the user story
- **User Story 1 (P1)**: Depends on Foundational
- **Polish (Final Phase)**: Depends on User Story 1

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other stories.

### Within Each User Story

- Model before service; service before view; view wired into ContentView before polish.

### Parallel Opportunities

- Phase 1 verification tasks are independent.
- `SearchViewModel` (T006) and `SearchResultsView` (T007) can run in parallel.
- Backend helper (T004) is independent of the Swift model (T003) and can start immediately in Phase 2.

---

## Parallel Example: User Story 1

```bash
# Launch the two independent UI pieces together:
Task: "Create SearchViewModel in SwiftMusicDL/ViewModels/SearchViewModel.swift"
Task: "Create SearchResultsView in SwiftMusicDL/Views/SearchResultsView.swift"

# Then wire into ContentView sequentially:
Task: "Wire SearchResultsView into ContentView"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 (search helper + Swift model/service)
2. Phase 3 (User Story 1): search box → results → download
3. **STOP and VALIDATE**: search + tap-to-download works independently
4. Ship/demo if desired

### Incremental Delivery

1. Add polish: rebuild `.app`, run quickstart, update README

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to a specific user story for traceability
- Each user story is independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
- Avoid: vague tasks, same-file conflicts, cross-story deps that break independence