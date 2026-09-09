# Implementation Plan: Spacious Layout & Navigation

**Branch**: `004-spacious-layout` | **Date**: 2026-08-19 | **Spec**: [spec.md](./spec.md)

## Summary

Rework the SwiftUI `ContentView` from a cramped single-column stack into a spacious,
multi-region layout. A persistent top header holds the paste/URL input and the search
box; a fluid content region below displays search results, preview, selection, download
progress, and completion — reflowing naturally as content is added instead of piling into
a narrow center column.

## Technical Context

**Language/Version**: Swift 5.9+ / SwiftUI

**Primary Dependencies**: SwiftUI only (existing); no new dependencies

**Storage**: None (presentational change)

**Testing**: `swift build`; manual/UI validation via `quickstart.md`

**Target Platform**: macOS 13.0+

**Project Type**: Desktop app frontend (presentational)

**Performance Goals**: Smooth reflow on content addition; no janky layout jumps

**Constraints**: Lightweight; no backend changes; uses available window width

**Scale/Scope**: 1 main view restructure (`ContentView.swift`) + minor helpers

## Constitution Check

*GATE checked against `.specify/memory/constitution.md`.*

- **II. Lightweight Client Agnosticism** — PASS: pure presentation, no backend coupling.
- **V. Simplicity & Performance** — PASS: only SwiftUI layout changes, no new deps.

## Project Structure

### Documentation (this feature)

```text
specs/004-spacious-layout/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # Phase 1 output (none — presentational)
```

### Source Code (repository root)

```text
SwiftMusicDL/
└── Views/
    └── ContentView.swift          # Restructured: header + fluid content region
```

**Structure Decision**: Keep the single view file; edit `ContentView.swift` to introduce a
header/content split with fluid width and region-spacing.