#!/usr/bin/env python3
"""Search for music tracks/albums and return JSON results.

Mirrors preview.py's pattern: run synchronously, print a single JSON line to
stdout. Combines multiple search sources and returns both tracks and albums:
  - Spotify (when authenticated) or public iTunes Search API
  - Deezer public (unauthenticated) API — adds explicit/clean editions
Results are deduplicated and sorted explicit-first.

Usage: python3 search.py <query>
"""
import json
import sys

SEARCH_LIMIT = 15


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"type": "error", "message": "No query provided"}), flush=True)
        return 2

    query = " ".join(sys.argv[1:]).strip()
    if not query:
        print(json.dumps({"type": "error", "message": "Empty query"}), flush=True)
        return 2

    try:
        from antra.core.config import load_config
        from antra.core.spotify import SpotifyClient
        from antra.sources.deezer_public import search_deezer
        from antra.utils.search_ordering import sort_explicit_first
        from antra.utils.matching import normalize

        cfg = load_config()
        client = SpotifyClient(
            cfg.spotify_client_id,
            cfg.spotify_client_secret,
            cfg.spotify_market,
            redirect_uri=cfg.spotify_redirect_uri,
            auth_storage_path=cfg.spotify_auth_path,
        )
        results = client.search_music(query, limit=SEARCH_LIMIT)
        results.extend(search_deezer(query, limit=12))

        # Drop clearly-filler derivative content (kids' covers, karaoke, tributes)
        # from all sources before merging, leaving official + live/remix releases.
        from antra.utils.search_refine import is_derivative

        results = [r for r in results if not is_derivative(r)]

        # Dedupe keeping the explicit/clean variant distinction: two rows are
        # duplicates only if they share (normalized title, artist, explicit flag).
        # This preserves both the explicit and clean edition of the same track.
        seen = set()
        deduped = []
        for r in results:
            key = (
                normalize(r.get("title") or ""),
                normalize(r.get("artist") or ""),
                r.get("is_explicit"),
            )
            if key in seen:
                continue
            seen.add(key)
            deduped.append(r)

        results = sort_explicit_first(deduped)

        # Cap results so the UI stays focused: sorting is already explicit-first, so
        # keeping the first N preserves both official explicit and clean editions
        # while dropping the long tail of low-relevance covers/mixes from other artists.
        results = results[:15]
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"type": "error", "message": f"Search failed: {e}"}), flush=True)
        return 1

    if not results:
        print(json.dumps({"type": "error", "message": "No results found"}), flush=True)
        return 1

    print(json.dumps({"type": "search_results", "query": query, "results": results}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())