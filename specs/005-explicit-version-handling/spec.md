# Feature Specification: Explicit Version Recognition & UI Revamp

**Feature Branch**: `005-explicit-version-handling`

**Created**: 2026-08-21

**Status**: Draft

**Input**: User description: "I write 'Walk Em Down' from 21 and Mustafa for example, I only get the non-explicit versions. Find a way to recognize explicit and non-explicit and show it. Also make them available to download. Also fix the UI, revamp the whole UI."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Always Get the Version I Actually Want (Priority: P1)

When searching for a known song, the user is currently served whichever version the
resolver happens to return — often the clean/non-explicit one. The user wants the app
to recognize which variant is explicit vs. non-explicit and, when both exist, make
either available to download instead of silently delivering the wrong one.

**Why this priority**: This is the user's core pain point and the trigger for this
request. Explicit and non-explicit variants are distinct releases that users actively
distinguish between (e.g., the "explicit" and "clean" editions of a track); the
resolver currently collapses them and hides the distinction.

**Independent Test**: Search "Walk Em Down" (21 Savage & Mustafa). If both an explicit
and a non-explicit variant resolve, the app MUST identify each one's explicit/non-
explicit status, surface that distinction in the results, and allow downloading each
variant independently.

**Acceptance Scenarios**:

1. **Given** the user has typed a query that resolves to multiple versions, **When**
   the results are shown, **Then** each result is labeled as Explicit or Non-explicit
   and the label is clearly visible.
2. **Given** an explicit result is shown, **When** the user selects it, **Then** the
   download succeeds and the delivered track is the explicit version.
3. **Given** a non-explicit (clean) result is shown, **When** the user selects it,
   **Then** the download succeeds and the delivered track is the clean version.

---

### User Story 2 - Revamp the Whole User Interface (Priority: P2)

The current UI is dated and cramped. The user wants a full visual redesign that is
modern, spacious, and pleasant to use, while keeping all existing functionality
(URL download, search, track selection, download progress).

**Why this priority**: The UI is how users experience the tool; a revamp makes the
app feel professional and improves usability, but it does not block the primary
"get the right version" outcome (P1). It can ship alongside or after the explicit/
non-explicit work.

**Independent Test**: All existing flows (paste URL, search, select track, download,
progress, error) remain usable in the new visual design.

**Acceptance Scenarios**:

1. **Given** the redesigned UI, **When** a user runs any existing flow, **Then** the
   layout uses a consistent, spacious, modern visual style (whitespace, typography,
   color, spacing).
2. **Given** the redesigned UI, **When** search results are displayed, **Then** the
   explicit/non-explicit label introduced in User Story 1 is present and readable.

---

### Edge Cases

- What happens when the resolver only finds a single version and its explicit status
  is unknown?
- How does the system label a track when the metadata provider does not expose an
  explicit/clean flag?
- What happens when two distinct explicit and non-explicit variants have identical
  titles and artists (how does the user tell them apart)?

---

### User Story 3 - Search Must Deliver the Same Track as a Pasted Link (Priority: P1)

A user who searches "Walk Em Down" by 21 Savage & Mustafa is currently served a
44.1 kHz MP3, whereas pasting `https://stage.tidal.com/track/263828941/u` returns the
96 kHz explicit FLAC. The user expects the searched result to resolve to the very same
track (same source ID, same quality) as the pasted link, so search is a faithful
substitute for pasting a link rather than a worse-quality fallback.

**Why this priority**: This is a correctness bug. Search and paste-link flows are
expected to be equivalent; delivering a lower-quality, format-different file from search
is a silent regression that defeats the purpose of the search feature.

**Independent Test**: Search "Walk Em Down (21 Savage & Mustafa)" and download the
matching result; the delivered file must be the same 96 kHz explicit FLAC track that
pasting the Tidal link `263828941` produces (same Tidal track ID, same encode/sample
rate, same explicitness).

**Acceptance Scenarios**:

1. **Given** the user searches "Walk Em Down", **When** they select the matching track,
   **Then** the download uses the same Tidal track ID derived for the pasted link
   (`263828941`) and delivers the 96 kHz explicit FLAC.
2. **Given** the same query, **When** the user downloads the searched result, **Then** the
   delivered file's sample rate, codec (FLAC), and explicit status match those of the
   pasted-link download, with no quality/format downgrade.
3. **Given** a search that resolves to multiple versions, **When** the explicit Tidal
   variant is selected, **Then** its Tidal ID routes through the HiRes pipeline just like a
   pasted link rather than the lower-bitrate fallback source.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST detect and expose whether each resolved track is
  explicit or non-explicit (clean), using the explicit/clean flags that the metadata
  providers already report (e.g., Spotify/Apple `is_explicit`, Tidal `explicit`).
- **FR-002**: The system MUST NOT silently collapse explicit and non-explicit variants
  of the same track; when both exist they MUST be surfaced as distinct, separately
  downloadable choices.
- **FR-002a**: In search results, explicit variants MUST be ordered above non-explicit
  variants of the same track (non-explicit versions listed at the bottom).
- **FR-003**: Users MUST be able to select either the explicit or the non-explicit
  version and have that specific version downloaded, with no default auto-selection;
  when both exist the user chooses which to download.
- **FR-004**: The UI MUST display an explicit/non-explicit indicator on each search
  result so users can tell variants apart at a glance.
- **FR-005**: When explicit status is unknown, the system MUST display the status as
  unknown rather than guessing incorrectly.
- **FR-006**: The UI MUST be revamped to a modern, spacious, consistent visual design
  applied to all existing panels and views, automatically adapting to the system's
  light/dark appearance.
- **FR-007**: The system MUST be able to derive a Tidal track ID from a selected
  search result (via the Tidal mirror's text search, backed by title/artist) and hand
  that Tidal ID to the download pipeline, so the same 96 kHz explicit master served by
  the Tidal mirror is downloadable from a search — not just from a pasted Tidal link.
- **FR-008**: The system MUST NOT allow a searched track to download as a different,
  lower-quality format than the same track pasted as a direct link; a search-selected
  track MUST resolve to the same source track and quality (e.g., the 96 kHz explicit
  FLAC) as the pasted-link equivalent for that track.
- **FR-009**: When a search result is downloaded, the delivered file MUST match the
  pasted-link download for the same track in sample rate, codec, and explicit status
  (no 44.1 kHz MP3 fallback when the Tidal HiRes master is available).
- **FR-010**: When deriving a Tidal ID from a search result, the system MUST use the
  first title + artist match returned by the Tidal mirror search, with no confirmation
  step; the top-ranked exact title/artist result is taken as the intended track.

### Key Entities *(include if feature involves data)*

- **SearchResult**: A resolved track claim with display metadata (title, artists,
  artwork) plus explicit status. Its source-specific ID selects a distinct downloadable
  variant.
- **ExplicitStatus**: A value describing a track as explicit, non-explicit (clean), or
  unknown, derived from provider flags.
- **TidalTrackRef**: A Tidal track ID derived from a search result (via Tidal mirror
  text search), used to route the download to the Tidal HiRes source.

## Clarifications

### Session 2026-08-21

- Q: When both an explicit and a non-explicit version of the same track exist, which version should the app prioritize by default? → A: Option C - Show both variants and let the user pick each time; no auto-preference.
- Q: For the "revamp the whole UI" request, what overall visual direction should the design follow? → A: Option C - Follow system light/dark automatically (adaptive).
- Q: When a track has both an explicit and a non-explicit version, how should they appear in search results? → A: Prioritize explicit versions at the top, with non-explicit versions listed at the bottom.
- Q: How should a search result become downloadable when the search source (Deezer/iTunes) can't itself be downloaded? → A: The searching should fetch the Tidal track ID via the Tidal mirror (TidalMirrorAdapter), then download that Tidal ID through the existing HiRes pipeline (mirror/hifi) — matching the 96 kHz explicit a directly-pasted Tidal link yields.
- Q: When a search result is mapped to a Tidal track for HiRes download, how should the system confirm it selected the correct track? → A: Option A - Use the first title + artist match returned by the Tidal mirror search, with no confirmation step (see FR-010).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Searching a track that exists in both an explicit and a clean edition
  surfaces both variants, labeled correctly (100% of tested tracks).
- **SC-002**: Downloading the explicit variant delivers an explicit track every time;
  downloading the clean variant delivers a clean track every time (100% correctness on
  tested examples).
- **SC-003**: A track whose explicit status is unknown is always labeled "unknown"
  and never mislabeled.
- **SC-004**: All existing core flows remain functional and testable in the redesigned
  UI; no regression in the accessibility of any P1 action.
- **SC-005**: For any track where a direct Tidal link yields the 96 kHz explicit FLAC,
  searching for and downloading that same track yields the identical file specs (sample
  rate 96 kHz, codec FLAC, explicit) — parity between search and paste-link (100% of
  tested tracks).

## Assumptions

- The backend already records explicit/clean flags from several providers (Spotify,
  Apple, Tidal); the feature reuses these flags rather than adding new providers.
- "Revamp the whole UI" applies to the existing mac/iOS SwiftUI frontend; the
  downloader's CLI behavior is unchanged.
- Explicit and non-explicit variants are modeled as separate selectable results within
  the existing search-result flow (no new navigation model required).
- The redesigned UI keeps the existing information architecture; the revamp is visual
  styling and layout, not a restructuring of features.