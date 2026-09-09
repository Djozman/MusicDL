# Research: Lightweight Swift Frontend

## Decision: Native SwiftUI macOS App
- **Rationale**: SwiftUI offers an ultra-lightweight, high-performance, native user interface framework perfect for a centered paste bar and card preview.
- **Alternatives Considered**: Web frontend (requires running local node server), AppKit (more boilerplate than SwiftUI).

## Decision: Backend Integration Strategy
- **Rationale**: Use Swift's `Process` or a lightweight local HTTP/JSON bridge to invoke the existing Python backend (`antra` CLI / python runner) pointing downloads to `~/Music`.
- **Alternatives Considered**: Rewriting download logic in Swift (violates backend-first reliability constitution).
