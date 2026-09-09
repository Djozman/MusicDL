# Research: Download Queue & Waitlist Management

**Date**: 2026-09-07
**Feature Spec**: [spec.md](spec.md)

## 1. Where should the queue live?

- **Decision**: The queue is coordinated in the macOS Swift client, driving Python
  backend subprocesses via JSON-line contracts. No new backend daemon or shared
  scheduler.
- **Rationale**: Today's architecture is subprocess-per-request (`BackendService`
  spawns `download.py`; `MainViewModel` awaits it). The queue naturally becomes the
  client-side orchestrator that manages *which backend subprocesses run and when*.
  This keeps the backend stateless and independently testable (Constitution II),
  requires no new server deployment, and the Python engine already parallelizes
  tracks within a single release via `ThreadPoolExecutor`.
- **Alternatives considered**:
  - A long-lived Python queue daemon/worker. Rejected: adds a persistent service,
    IPC session management, and lifecycle complexity disproportionate to a client
    tool; the client already owns the download lifecycle today.
  - Queue inside `antra.core.service`. Rejected: couples a library core to a UI
    orchestration concern and complicates the statelessness principle.

## 2. Concurrency model

- **Decision**: Client-driven sequential slot model: the queue has a small number of
  active slots (default **1** active download at a time, config cap of `N` concurrent
  subprocesses). Within an active slot, the engine already downloads an album/playlist's
  tracks in parallel its own way. Once a slot's subprocess exits, the next pending
  queue item is promoted to active automatically.
- **Rationale**: FR-002 requires enqueueing while one is active without interrupting
  it; a slot model satisfies this. Default 1 avoids I/O thrash and duplicate partial
  writes to the same output dir; a small cap (e.g., 2-3) is a cheap optional knob for
  users with fast disks. FR-003 (auto-advance) is the natural slot promotion rule.
- **Alternatives considered**:
  - One subprocess per track across releases. Rejected: introduces parallel writes
    into a shared library folder, higher collision/failure surface, and corrupts the
    "one release at a time" mental model.
  - Reusing only the engine's internal parallelism and forcing all enqueues to wait
    in one long blocking call. Rejected: cannot reflect per-item queue states or allow
    retry/remove of individual failed items (FR-007/008).

## 3. Observability & progress contract

- **Decision**: Reuse the existing per-track `event` JSON-line contract already
  emitted by `download.py` (`track_started`, `track_completed`, `track_skipped`,
  `track_failed`) and the `download_summary` line, plus add a lightweight queue-level
  event/notification from the client's own state transitions. No new heavy streaming
  framework.
- **Rationale**: The Swift `MainViewModel` already parses these exact events; mapping
  them to queue-item states is cheap and keeps one contract (Constitution IV/II).
- **Alternatives considered**: A dedicated metrics/socket protocol. Rejected: overkill
  for a single-user client; JSON-line stdout is already proven in this codebase.

## 4. Output directory propagation

- **Decision**: Backend download helpers accept an explicit output-directory
  argument (`--out PATH`) that overrides the env var/`~/Music` default; the Swift
  client passes the user's chosen per-session directory to every subprocess.
- **Rationale**: FR-009/010 require a user-selectable per-session directory, not a
  hard-coded one. `antra_dl.py` already has `resolve_out_dir` and `OUTPUT_DIR` env
  support; `BackendService.makeProcess` already sets `OUTPUT_DIR`. Extending the
  download helper with an explicit arg keeps the value explicit and overridable.
- **Alternatives considered**: Relying solely on `~/Music`. Rejected: violates FR-010.
  Config-file persistence of the choice out of scope (per-session, FR-016).

## 5. Pause / re-download on interruption

- **Decision**: On app quit/interruption, in-progress items are reflected as
  **paused** in-session and are re-downloaded **from scratch** on retry/recovery
  (never appended). For an album/playlist, already-completed tracks are retained and
  only the in-progress plus not-yet-downloaded tracks are re-downloaded.
- **Rationale**: Per user decision (FR-016/017/018), partial appends risk corruption;
  the engine already deletes/discards partial files (`_discard_file`) and treats a
  failed/completed track independently, so retaining completed album tracks while
  re-doing the rest fits the existing engine behavior.
- **Alternatives considered**: Resuming partial downloads by byte-range append.
  Rejected: corruption risk (explicit user choice). Persisting the queue across
  restarts. Rejected: explicitly per-session (FR-016).

## 6. Duplicate handling

- **Decision**: Duplicate items (same URL) already in the queue trigger a
  confirmation prompt rather than silent re-add or silent reject (per spec edge case
  and FR-006/Assumptions).
- **Rationale**: Matches the assumption in the spec and avoids surprising the user
  with either silent file overwrites or silent dropped requests.
- **Alternatives considered**: Auto-reject duplicates. Rejected: user may legitimately
  want an explicit re-download. Auto-add duplicates without asking. Rejected: risks
  wasted bandwidth/disk.

## 7. Queue capacity

- **Decision**: A bounded waitlist capacity (spec: "reasonable capacity"); when full,
  the user is shown a clear message and the item is not added.
- **Rationale**: Prevents runaway memory/disk for very large enqueues; bounded,
  graceful behavior satisfies the spec edge case.
- **Alternatives considered**: Unlimited capacity. Rejected: unbounded memory/disk
  risk with no user value.