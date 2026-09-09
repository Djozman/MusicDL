# Research: Spacious Layout & Navigation

## Decision: Header + fluid content region (top-to-bottom flow)
- **Rationale**: Keep the paste bar and search box in a fixed top header, and let search
  results, preview, selection, and download progress fill a content region below. This
  stops the "cramped center column" and lets content spread across available width,
  reflowing as items are added.
- **Alternatives considered**: Sidebar/split view (more platform chrome than needed);
  tabbed sections (over-engineering for a single search-and-download screen).

## Decision: Expand max widths and use natural spacing
- **Paste bar**: widen to near-full width (stays one row) so it feels like a search/URL
  field rather than a tiny centered box.
- **Search results**: render in an obvious results area (below the input) with a compact
  row layout and generous padding, instead of a cramped mini-list.

## Decision: Fluid/reflowing content, not overlays
- New content (preview, selection, download) pushes existing content down/around via the
  outer VStack rather than stacking in a fixed column.
- Loading spinners stay inside their region to avoid jarring page jumps.

## Decision: Clear spacing + grouping
- Use consistent section spacing (24) and rounded cards to visually separate input,
  results, preview, and status.
- A dedicated status area keeps progress/errors out of the way of input.