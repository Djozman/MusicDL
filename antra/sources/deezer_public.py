"""Public (unauthenticated) Deezer music search.

Deezer's public API (``api.deezer.com``) requires no login and returns the
explicit flag on each track — unlike the iTunes public search, which hides
explicit editions. Used as an additional best-effort search source so users can
find explicit and clean editions of a track.
"""
import logging
from typing import List

logger = logging.getLogger(__name__)

_BASE = "https://api.deezer.com/search"


def _is_explicit(item: dict) -> bool:
    """Deezer marks explicitness via ``explicit_lyrics`` / ``explicit_content_lyrics``.

    ``explicit_content_lyrics`` is 1 (explicit), 6 (explicit remastered),
    0 (clean), etc. We treat any non-zero ``explicit_lyrics`` as explicit.
    """
    return bool(item.get("explicit_lyrics")) or int(item.get("explicit_content_lyrics") or 0) != 0


def search_deezer(query: str, limit: int = 8) -> List[dict]:
    """Search Deezer's public catalog and return normalized result dicts.

    Each result matches the frontend search contract:
        {type, title, artist, album, artwork_url, track_url, source, is_explicit}
    `track_url` is a Deezer track URL the backend resolver can download.
    Empty list on error.
    """
    try:
        import requests

        resp = requests.get(_BASE, params={"q": query, "limit": limit}, timeout=12)
        resp.raise_for_status()
        data = resp.json()
        if data.get("error"):
            logger.debug("[Deezer] Public search error: %s", data["error"])
            return []
    except Exception as e:  # noqa: BLE001
        logger.debug(f"[Deezer] Public search failed for '{query}': {e}")
        return []

    results: List[dict] = []
    for it in data.get("data", []) or []:
        if not it.get("readable", True):
            continue
        track_id = it.get("id")
        if not track_id:
            continue
        artist = ((it.get("artist") or {}).get("name")) or "Unknown Artist"
        album_obj = it.get("album") or {}
        cover = (album_obj.get("cover_xl")
                 or album_obj.get("cover_big")
                 or album_obj.get("cover_medium")
                 or album_obj.get("cover")
                 or "")
        title = it.get("title") or "Unknown Track"
        results.append({
            "type": "track",
            "title": title,
            "artist": artist,
            "album": album_obj.get("title") or "Unknown Album",
            "subtitle": "",
            "artwork_url": cover,
            "track_url": f"https://www.deezer.com/track/{track_id}",
            "source": "deezer",
            "is_explicit": True if _is_explicit(it) else False,
        })
    return results