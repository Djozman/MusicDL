# Tasks: Lightweight Swift Frontend with Central Download Bar

**Input**: Design documents from `/specs/001-swift-frontend-bar/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Mobile / Desktop (Swift)**: `SwiftMusicDL/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic SwiftUI app structure

- [ ] T001 Initialize Swift macOS package/app structure in `SwiftMusicDL/` per implementation plan
- [ ] T002 [P] Configure project configuration, assets, and target settings in `SwiftMusicDL.xcodeproj`
- [ ] T003 [P] Create directory structure for Views, ViewModels, Models, and Services under `SwiftMusicDL/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data models and backend communication service that MUST be complete before any user story UI can be fully implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create `DownloadRequest` and `TrackMetadata` models in `SwiftMusicDL/Models/TrackMetadata.swift`
- [ ] T005 Create `DownloadState` model and status enum in `SwiftMusicDL/Models/DownloadState.swift`
- [ ] T006 Implement backend bridge service using Swift `Process` or HTTP client in `SwiftMusicDL/Services/BackendService.swift` to invoke `python3 -m antra.json_cls`

---

## Phase 3: User Story 1 - Paste Link and Preview Track (Priority: P1) 🎯 MVP

**Goal**: Provide a clean minimalist UI with a centered search/paste bar where users can paste any music link to instantly view track artwork and preview details.

**Independent Test**: Paste a valid link into the central bar and verify that album artwork, title, and artist appear instantly.

### Implementation for User Story 1

- [ ] T007 [P] [US1] Create main container view and centered paste bar layout in `SwiftMusicDL/Views/ContentView.swift`
- [ ] T008 [P] [US1] Create track preview card view with artwork image loader in `SwiftMusicDL/Views/PreviewCardView.swift`
- [ ] T009 [US1] Implement MainViewModel state management for URL input, metadata fetching, and preview display in `SwiftMusicDL/ViewModels/MainViewModel.swift`
- [ ] T010 [US1] Integrate backend metadata inspection API call into `MainViewModel` in `SwiftMusicDL/ViewModels/MainViewModel.swift`
- [ ] T011 [US1] Add download confirmation prompt UI once preview metadata is loaded in `SwiftMusicDL/Views/DownloadConfirmationView.swift`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (paste link -> preview shows up with confirmation prompt).

---

## Phase 4: User Story 2 - One-Click Download to Default Music Directory (Priority: P2)

**Goal**: Allow the user to confirm the download prompt so the track downloads frictionlessly directly to `~/Music` (`users/amm/music`).

**Independent Test**: Confirm the download prompt and verify that the audio file successfully lands in `~/Music`.

### Implementation for User Story 2

- [ ] T012 [US2] Implement download trigger and execution action in `MainViewModel` using `BackendService` targeting `~/Music` in `SwiftMusicDL/ViewModels/MainViewModel.swift`
- [ ] T013 [US2] Add download progress indicator and success/error status notifications in `SwiftMusicDL/Views/StatusView.swift`
- [ ] T014 [US2] Integrate status feedback into the central UI flow in `SwiftMusicDL/Views/ContentView.swift`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently (paste link -> preview -> confirm download -> files land in `~/Music`).

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements, error handling polish, and quickstart validation

- [ ] T015 [P] Add README and developer instructions for running Swift frontend alongside Python backend in `SwiftMusicDL/README.md`
- [ ] T016 Code cleanup, layout refinements, and SwiftUI styling polish across all views
- [ ] T017 Run quickstart.md end-to-end validation scenario

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User Story 1 (P1) → User Story 2 (P2)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2)
- **User Story 2 (P2)**: Builds upon User Story 1's preview and confirmation flow to trigger downloads.

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Centered bar & preview)
4. **STOP and VALIDATE**: Test link pasting and preview rendering independently

### Incremental Delivery
1. Add User Story 2 (One-click download to `~/Music`)
2. Polish & cross-cutting concerns
