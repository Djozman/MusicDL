# Implementation Plan: Download Queue & Waitlist Management

**Branch**: `006-download-queue` | **Date**: 2026-09-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-download-queue/spec.md`

## Summary

Add a per-session download queue so the user can enqueue tracks, albums, and
playlists while another download is active, observe each item's state (pending,
active, failed, done, paused), retry/remove failed items, and choose the output
directory per session. Downloading starts only after a pasted link is resolved to
a preview and the user confirms adding it to the queue.

The existing pipeline (`antra.core.service.AntraService`) already fetches and
downloads tracks and the engine parallelizes tracks within a single release via a
`ThreadPoolExecutor`. What does **not** exist today is a queue coordinating the
*backend subprocesses* on the client side so multiple releases can be managed
concurrently and the UI remains responsive. The queue lives in the Swift client as
the orchestrator of backend subprocesses, with a JSON-line protocol being the
shared contract.

## Technical Context

**Language/Version**: Swift (existing macOS frontend, `SwiftMusicDL`) + Python 3.10+
(backend, `antra`/`download.py` helpers)

**Primary Dependencies**: Combine (Swift), Foundation `Process` (already used by
`BackendService`), existing `antra` Python pipeline. No new runtime dependencies
required for queueing (client-coordinated subprocess queue).

**Storage**: None required — the queue is explicitly per-session (FR-016), held in
memory in the Swift client. No persistence layer needed.

**Testing**: Python pytest (existing `tests/unit`, `tests/contract`) for backend
helpers/protocols; Swift XCTest for the queue model/logic
(`tests/SwiftMusicDLModels`, add client-side queue tests).

**Target Platform**: macOS desktop app (LTS macOS, current SwiftUI frontend layout).

**Project Type**: desktop-app (SwiftUI client) driving a CLI subprocess backend; the
client is the orchestrator.

**Performance Goals**: Queue must accept a new enqueue instantly (< 200ms UI
response) while a download is running; enqueuing and state updates must not block
the main thread; no "app not responding" during a large queue.

**Constraints**: Subprocess-per-request model — concurrent downloads require more
than one backend `Process`; disk I/O and network are the bottleneck, so a bounded
concurrent downloader (default 1 active download at a time per FR-002, configurable
up to a small N) is appropriate.

**Scale/Scope**: Consumer music downloads — tens of items in a queue, single user,
single machine. Not a multi-user/server workload.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Downloader-First Reliability**: Queueing MUST keep the backend source-agnostic
  and expose clean JSON/CLI entry points. PASS — queue is client-side orchestration
  of the existing subprocess contract; the engine's concurrency is reused.
- **II. Lightweight Client Agnosticism**: Any new backend surface MUST be stateless
  JSON-line protocols (same shape as existing `download.py` events). PASS.
- **III. Test-Driven Verification (NON-NEGOTIABLE)**: Queue state machine, protocol
  parsing, and output-directory handling MUST have automated unit + integration
  tests. PASS — plan adds queue-model tests and backend protocol tests.
- **IV. Observability & Graceful Error Handling**: Failed items MUST surface a clear
  state and remain retryable/removable without blocking the queue (FR-015). PASS.
- **V. Simplicity & Performance**: Prefer client-side queue over building a new
  server/daemon; no new heavy framework. PASS — complexity is justified in the
  table below only where needed.

All gates PASS. No complexity violations requiring justification beyond the queue
coordinator itself (see Complexity Tracking).

## Project Structure

### Documentation (this feature)

```text
specs/006-download-queue/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (backend JSON-line protocol)
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created here)
```

### Source Code (repository root)

```text
SwiftMusicDL/
├── Models/
│   └── QueueEntry.swift        # NEW: per-queue-item entity + state
│   └── DownloadQueue.swift     # NEW: queue model, state machine, sequence logic
├── Services/
│   └── BackendService.swift    # EXTEND: queue-aware subprocess runner,
│                               #         output-dir wiring, signal support
├── ViewModels/
│   └── MainViewModel.swift     # EXTEND: submit → confirm → enqueue; observability
│   └── QueueViewModel.swift    # NEW: observable queue list, retry/remove
└── Views/
    ├── ContentView.swift       # EXTEND: queue panel + output-dir picker
    └── QueueView.swift         # NEW: waitlist/status list UI

SwiftMusicDL/Modules/QueueEngine/   # if extracted for testability:
├── QueueStateMachine.swift
└── QueueProtocol.swift

tests/SwiftMusicDLModels/
└── DownloadQueueTests.swift   # NEW: XCTest for queue logic

# Backend side (protocol + tests), reuse download.py:
tests/contract/
└── test_queue_protocol.py     # NEW: new JSON-line contract
```

**Structure Decision**: Keep the queue almost entirely in the existing macOS Swift
client, coordinated over JSON-line subprocess contracts already established by
`BackendService`/`download.py`. Backend changes are limited to (a) accepting an
explicit output directory argument (rather than only env/`~/Music`) and (b) emitting
the existing per-track events reliably plus optional pause semantics — no new
daemon, no new server, no shared scheduler. The queue coordinator is the only new
non-trivial component and is testable independently.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Client-side queue coordinator (new component) | Must run N releases concurrently while UI stays responsive | A single blocking subprocess (today's model) cannot enqueue while one is active (FR-002). |
| Bounded concurrent downloader (default 1, cap small N) | Concurrency while avoiding I/O thrash and duplicate file writes | Unbounded parallelism raises disk contention and partial-file corruption risk. |
| Explicit `--out`/output-dir arg to backend | User-selectable, non-hard-coded directory (FR-009/010) | Relying only on a hard-coded `~/Music` violates FR-010. |

## Phase 0: Research

Research findings are consolidated in `research.md`. Key resolutions:
queue placement (client-side), concurrency model (bounded sequential client queue
around the engine's intra-album parallelism), progress/observability contract
(reuse existing `event` JSON-line), output-dir propagation (`--out` arg + env),
pause/re-download semantics (re-download from scratch, per FR-017).

## Phase 1: Design

Phase 1 artifacts:
- `data-model.md` — queue item entity, states, transitions (pending → active →
  done/failed → retry/remove; interrupted → paused), queue + slot model.
- `contracts/` — the JSON-line protocol additions/contract between Swift client and
  Python backend (download invocation, per-track events, summary, output dir).
- `quickstart.md` — end-to-end runnable validation scenarios mapping to the spec's
  acceptance scenarios and success criteria.

> Constitution check re-evaluated after design: all gates still PASS (client-side
> orchestration, stateless JSON contract, tested queue state machine, graceful
> failure handling, minimal new components).