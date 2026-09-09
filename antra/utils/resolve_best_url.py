"""Resolve the best download URL for a search result.

Search results come from lightweight public sources (Deezer/iTunes/Spotify) whose
``track_url`` is a page only that source can download — which often misses the
user's configured HiRes provider (e.g. a Tidal mirror serving 96 kHz explicit).

This helper takes a search result (title/artist + fallback URL) and resolves it to
a cross-platform track via Odesli, preferring a Tidal stream URL when available so
the download routes to the Tidal HiRes source (mirror/hifi) and yields the same
explicit 96 kHz master the user gets from pasting a Tidal link directly.
"""
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def _tidal_url(track_id: Optional[str]) -> Optional[str]:
    if not track_id:
        return None
    tid = str(track_id).strip()
    if not tid or not tid.isdigit():
        return None
    return f"https://tidal.com/track/{tid}"


def resolve_best_download_url(title: str, artist: str, fallback_url: str,
                              artist_list=None) -> dict:
    """Resolve ``(title, artist)`` to the best download URL for the pipeline.

    Returns ``{ "url": str, "source": str, "resolved": bool }``.
    Prefers a Tidal URL (HiRes source) when Odesli finds one; otherwise returns
    ``fallback_url`` unchanged.
    """
    result = {"url": fallback_url or "", "source": "", "resolved": False}
    if not title:
        return result

    from antra.core.models import TrackMetadata
    from antra.sources.odesli import OdesliEnricher

    artists = [a for a in (artist_list or []) if a] or ([artist] if artist else [])
    track = TrackMetadata(
        title=title,
        artists=artists or ["Unknown Artist"],
        album="",
    )

    try:
        links = OdesliEnricher().resolve(track)
    except Exception as e:  # noqa: BLE001
        logger.warning("[ResolveBestURL] Odesli resolve failed for '%s': %s", title, e)
        return result

    tidal = links.get("tidal")
    if tidal:
        url = _tidal_url(tidal)
        if url:
            return {"url": url, "source": "tidal", "resolved": True}

    # No Tidal link — keep the original search URL (still downloadable if its
    # source is configured).
    return result