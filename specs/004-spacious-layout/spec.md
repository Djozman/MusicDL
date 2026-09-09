# Spacious Layout & Navigation

## User Story 1 - Spacious, Non-Stacking Layout (Priority: P1)

**Goal**: Replace the cramped single-column stack with an airy, easily-navigable
layout that spreads content across the screen and reflows/moves items gracefully as new
content appears (e.g. search results, preview card, downloading panel).

**Rationale**: The current UI stacks everything in a narrow middle column, so adding a
search result or preview pushes other content awkwardly and feels cluttered. A spaced,
responsive layout makes the app feel lighter and easier to navigate.

## User Scenarios & Testing

### Scenario 1: Content reflows instead of cramping (P1)
As a user, when I paste a link or search, new panels (preview, results) should appear in a
way that avoids awkward crowding in a single column.

**Acceptance Criteria**:
1. When content is added (results list, preview card, download panel), surrounding items
   reposition smoothly rather than stacking in one narrow column.
2. The layout uses available screen width (not just a fixed center column).

### Scenario 2: Clear visual hierarchy / navigation (P1)
As a user, I can quickly understand where to type, where results appear, and where my
download progress is.

**Acceptance Criteria**:
1. The page has clear regions: top input/search, results/preview area, download status.
2. Navigation between these is obvious (no hidden/overlapping content).

## Requirements

### Functional Requirements
- **FR1**: The app MUST distribute content across available window width rather than a
  single narrow column.
- **FR2**: New content (search results, preview, download progress) MUST appear in a
  responsive area that reflows as items are added.
- **FR3**: The layout MUST maintain clear vertical/visual separation between search
  input, results, preview, and download status.
- **FR4**: Progress/loading indicators and completion states MUST not cause layout jumps
  that obscure other content.

## Success Criteria
- The main window uses a spacious, multi-region layout.
- Adding content reflows smoothly without a cramped central stack.
- Users can find input, results, preview, and progress without confusion.

## Assumptions
- macOS desktop, resizable window.
- Layout change is purely presentational; no backend changes.
