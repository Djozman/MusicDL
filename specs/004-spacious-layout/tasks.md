# Tasks: Spacious Layout & Navigation

**Input**: Design documents from `/specs/004-spacious-layout/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- **Desktop app**: `SwiftMusicDL/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the existing Swift package and bundle build cleanly.

- [x] T001 [P] Verify the Swift package builds cleanly with `swift build`
- [x] T002 [P] Confirm `./build_app.sh` assembles and signs the `.app`

---

## Phase 2: User Story 1 - Spacious Layout & Navigation (Priority: P1) 🎯 MVP

**Goal**: Restructure the main view from a cramped single-column stack into a spacious,
multi-region layout with a persistent top header (paste bar + search) and a fluid content
region that reflows as content appears.

**Independent Test**: Resize the window wide/narrow; confirm input stays in a top header
and adding search results, preview, or a download panel reflows content smoothly across
available width without cramming into the center column.

### Implementation for User Story 1

- [x] T003 [US1] Restructure `ContentView` in `SwiftMusicDL/Views/ContentView.swift` to a top `VStack` header (paste bar + Inspect + search box) separated from a fluid content region, replacing the current centered `Spacer()`-constrained single-column stack
- [x] T004 [US1] Widen the paste bar to use available width (remove `.frame(maxWidth: 600)` constraint) in `SwiftMusicDL/Views/ContentView.swift`
- [x] T005 [US1] Separate content rendering (results, preview, selecting, downloading, completed, error) into its own region below the header with consistent 24px section spacing in `SwiftMusicDL/Views/ContentView.swift`
- [x] T006 [US1] Ensure new content reflows (pushes/expands the fluid region) rather than overlaying or stacking in a narrow column in `SwiftMusicDL/Views/ContentView.swift`
- [x] T007 [US1] Verify loading/completion indicators stay within their own region and do not cause jarring layout jumps in `SwiftMusicDL/Views/ContentView.swift`

**Checkpoint**: At this point, User Story 1 is complete — the app uses a spacious,
multi-region layout that reflows content naturally.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Validation, docs, and final packaging.

- [x] T008 Rebuild and run `./build_app.sh`, then launch `SwiftMusicDL.app`
- [x] T009 Run `specs/004-spacious-layout/quickstart.md` validation scenarios end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verification only
- **User Story 1 (P1)**: Depends on Setup
- **Polish (Final Phase)**: Depends on User Story 1

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other stories.

### Within Each User Story

- Header first (T003, T004), then content-region separation and reflow (T005–T007).

### Parallel Opportunities

- Phase 1 verification tasks are independent (T001, T002).
- All User Story 1 tasks edit the same file (`ContentView.swift`) so must run sequentially.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup verification
2. Phase 2: User Story 1 layout restructure
3. **STOP and VALIDATE**: resize + reflow works
4. Polish: rebuild `.app`, run quickstart

---

## Notes

- [P] tasks = different files, no dependencies
- User Story 1 edits only `SwiftMusicDL/Views/ContentView.swift` (sequential)
- Each user story is independently completable and testable
- Avoid: vague tasks, same-file conflicts that break independence