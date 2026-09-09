#!/usr/bin/env python3
"""Upgrade a search result to the best download URL for the HiRes pipeline.

Given a search result's title/artist (and optional fallback URL), resolve it via
the configured Tidal mirror's text search (FIRST title+artist match, no
confirmation — FR-010) and return the preferred Tidal stream URL when available.
The frontend then feeds this URL to the existing preview/download flow so the
HiRes Tidal source (96 kHz explicit) is used — matching what pasting a Tidal link
produces (US3 / FR-007, FR-008, FR-009, SC-005).

Usage: python3 resolve_track.py "<title>" "<artist>" [fallback_url]
Output: {"type": "resolve", "title": ..., "artist": ..., "url": ..., "source": ..., "resolved": bool}
"""
import json
import sys
import logging

logger = logging.getLogger(__name__)


def _tidal_mirror_settings():
    """Return (mirror_url, api_key, preferred_output_format) from config + manifest.

    Mirrors antra.core.service AntraService.ensure_sources: config env var takes
    precedence, otherwise the endpoint manifest's private mirror URL is used; the
    mirror API key comes from the manifest (falling back to the user key).
    """
    from antra.core.config import load_config
    from antra.core.endpoint_manifest import load_endpoint_manifest

    cfg = load_config()

    def mirror_url(env_val, manifest_attr):
        if env_val:
            return env_val
        try:
            manifest = load_endpoint_manifest()
            return getattr(manifest, manifest_attr, "") or ""
        except Exception as e:  # noqa: BLE001
            logger.warning("[ResolveTrack] endpoint manifest unavailable: %s", e)
            return ""

    api_key = (getattr(cfg, "antra_api_key", "") or "").strip()
    manifest_key = ""
    try:
        manifest = load_endpoint_manifest()
        manifest_key = (getattr(manifest, "api_key", "") or "").strip()
    except Exception as e:  # noqa: BLE001
        logger.warning("[ResolveTrack] endpoint manifest unavailable: %s", e)

    url = mirror_url(getattr(cfg, "tidal_mirror_url", "") or "", "mirror_tidal")
    return url, (manifest_key or api_key), (getattr(cfg, "output_format", "") or "source")


def resolve_to_tidal_url(title: str, artist: str, fallback_url: str = "") -> dict:
    """Resolve (title, artist) to the best (Tidal) download URL.

    Runs TidalMirrorAdapter.search() (title/artist text search) and returns the
    FIRST title+artist match's Tidal stream URL (FR-010, no confirmation step).
    When no Tidal match is found, returns the fallback URL unchanged.
    """
    result = {"url": fallback_url or "", "source": "", "resolved": False}
    if not title:
        return result

    from antra.core.models import TrackMetadata
    from antra.sources.tidal_mirror import TidalMirrorAdapter

    mirror_url, mirror_api_key, preferred_output_format = _tidal_mirror_settings()
    if not mirror_url:
        logger.info("[ResolveTrack] No Tidal mirror configured; keeping fallback URL")
        return result

    adapter = TidalMirrorAdapter(
        mirror_url=mirror_url,
        api_key=mirror_api_key,
        preferred_output_format=preferred_output_format,
    )
    if not adapter.is_available():
        logger.info("[ResolveTrack] Tidal mirror unavailable; keeping fallback URL")
        return result

    track = TrackMetadata(
        title=title,
        artists=[artist] if artist else ["Unknown Artist"],
        album="",
    )
    try:
        hit = adapter.search(track)
    except Exception as e:  # noqa: BLE001
        logger.warning("[ResolveTrack] Tidal text search failed: %s", e)
        return result

    if hit is None or not getattr(hit, "stream_id", ""):
        logger.info("[ResolveTrack] No Tidal match for '%s' — %s; keeping fallback URL", title, artist)
        return result

    # Wait: search() may return early via Odesli or ISRC paths which also produce a
    # stream_id. We rely on the caller's title/artist as the intended identity and
    # accept the returned stream_id as the FIRST match (FR-010). Stream IDs for
    # explicit/clean variants may differ; we take whatever the mirror returned.
    tid = str(hit.stream_id).strip()
    if not tid or not tid.isdigit():
        return result

    result.update({
        "url": f"https://tidal.com/track/{tid}",
        "source": hit.source or "tidal_mirror",
        "resolved": True,
    })
    return result


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({"type": "error", "message": "title and artist required"}), flush=True)
        return 2

    title = sys.argv[1]
    artist = sys.argv[2]
    fallback = sys.argv[3] if len(sys.argv) > 3 else ""

    try:
        resolved = resolve_to_tidal_url(title, artist, fallback)
        print(json.dumps({
            "type": "resolve",
            "title": title,
            "artist": artist,
            "url": resolved.get("url", ""),
            "source": resolved.get("source", ""),
            "resolved": resolved.get("resolved", False),
        }), flush=True)
        return 0
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"type": "error", "message": f"Resolve failed: {e}"}), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())