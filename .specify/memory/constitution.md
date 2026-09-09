<!--
Sync Impact Report:
- Version change: 1.0.1 → 1.1.0
- Modified principles: I. Downloader-First Reliability (extended: concurrent queueing & waitlist)
- Added sections: none
- Removed sections: none
- Follow-up TODOs: none
-->
# MusicDL Constitution

MusicDL is a music downloader: a set of CLI tools built on the Antra pipeline that
recognizes track/album/playlist URLs from supported services and downloads each
track as tagged, lossless-grade audio.

## Core Principles

### I. Downloader-First Reliability
The downloader must remain robust, highly concurrent, and source-agnostic,
providing clean CLI and JSON entry points for all music downloading and management
functionality across multiple sources (Spotify, Tidal, Amazon Music, Qobuz, Deezer,
Apple Music, SoundCloud, YouTube Music, etc.). Downloads MUST be queued and managed
through an explicit concurrent queue with a user-visible waitlist, so multiple items
can be enqueued while another is actively downloading, and the queue state (active,
pending, failed, done) MUST remain observable at all times.

### II. Lightweight Client Agnosticism
Clients (such as frontends in Swift, CLI tools, or web UIs) communicate with the
backend via stateless, efficient interfaces (JSON/CLI protocols), keeping the
backend lightweight, modular, and decoupled from platform-specific UI concerns.

### III. Test-Driven Verification (NON-NEGOTIABLE)
All core downloading pipelines, metadata taggers, transcoders, source resolvers, and
queue/waitlist management logic must be thoroughly tested with automated unit and
integration tests. Changes must maintain or increase test coverage and verify
successfully before release.

### IV. Observability & Graceful Error Handling
Network failures, rate limits, missing tracks, or unsupported URLs must be handled
gracefully with clear, structured error responses and detailed logging to ensure
transparency and debuggability. Queue failures MUST surface a clear status and retain
the failed item in the waitlist for retry or removal.

### V. Simplicity & Performance
Avoid unnecessary abstractions. Code paths for downloading, matching, and organizing
audio files must be optimized for speed, low resource consumption, and minimal
external dependencies.

## Technical Constraints

### Architecture & Tech Stack
- **Backend:** Python 3.10+ with asynchronous request support, modular source
  plugins, and robust metadata tagging/transcoding utilities.
- **Output:** Tagged lossless files by default, with configurable output formats
  (`source`, `flac`, `alac`, `mp3`, `lossless-24`, …) and a user-selectable output
  directory (default `~/Music`) that MUST be configurable per session, not hard-coded.
- **Queueing:** A single concurrent download queue with a durable, observable
  waitlist; a pasted link MUST resolve to a fetchable item and be added to the queue
  for explicit confirmation rather than blocking a running download.
- **APIs & Interoperability:** JSON input/output protocols and CLI entry points
  (`antra_dl.py`, `tidal_dl.py`) enabling cross-platform frontends (e.g., macOS/iOS
  Swift apps).
- **Dependencies:** Explicitly managed, vetted dependencies; avoid bloated
  frameworks where standard library or lightweight modules suffice.

## Development Workflow

### Code Quality & Standards
- Code must adhere to strict type checking and linting standards.
- All core features, bug fixes, and source integrations must be verified with
  automated test suites, including queue concurrency and waitlist behavior.
- Code reviews must enforce modularity, separation of concerns between core
  downloader logic and client integrations, and robust error handling.

## Governance

### Amendments & Compliance
- This constitution supersedes all other informal development practices and ad-hoc
  conventions.
- Amendments require version bumps, documented rationale, and verification against
  existing client integration stability.
- All contributions and pull requests must verify compliance with core principles,
  particularly downloader reliability, queue/waitlist behavior, test coverage, and
  clean client decoupling.

**Version**: 1.1.0 | **Ratified**: 2026-08-18 | **Last Amended**: 2026-09-07