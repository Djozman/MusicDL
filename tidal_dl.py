"""
tidal_dl — tiny CLI that asks for a Tidal track or album ID/URL, recognizes
the release via your Tidal mirror server, and downloads the tracks as lossless FLAC.

Reuses Antra's existing components:
  - load_config()        reads .env / environment (TIDAL_MIRROR_URL, ANTRA_API_KEY)
  - TidalMirrorAdapter   downloads 24-bit HiRes FLAC from the mirror.

Usage:
  python tidal_dl.py
  python tidal_dl.py --id 12345678                  (track)
  python tidal_dl.py --id https://tidal.com/browse/track/12345678
  python tidal_dl.py --id 123456789                (album)
  python tidal_dl.py --id https://tidal.com/browse/album/123456789
"""
import argparse
import os
import re
import sys

import requests

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from antra.core.config import load_config
from antra.core.endpoint_manifest import load_endpoint_manifest
from antra.core.models import SearchResult, AudioFormat
from antra.sources.tidal_mirror import TidalMirrorAdapter


def extract_kind_id(raw: str):
    """Return (kind, id) for a bare numeric ID or a full Tidal URL.

    Bare numeric IDs default to 'track' unless the flag is given.
    """
    raw = (raw or "").strip()
    if not raw:
        raise ValueError("Empty Tidal ID/URL.")
    if raw.isdigit():
        return "track", raw
    m = re.search(r"tidal\.com/(?:browse/)?(?P<kind>track|album|playlist)/([A-Za-z0-9_-]+)", raw)
    if not m:
        raise ValueError("Not a Tidal track/album ID or tidal.com/track|album/… URL.")
    return m.group("kind"), m.group(2)


def resolve_mirror(cfg) -> str:
    """Find the Tidal mirror base URL from config or endpoint manifest."""
    url = (getattr(cfg, "tidal_mirror_url", "") or "").strip().rstrip("/")
    if url:
        return url
    try:
        manifest = load_endpoint_manifest()
        url = (getattr(manifest, "mirror_tidal", "") or "").strip().rstrip("/")
    except Exception:
        url = ""
    if not url:
        raise RuntimeError(
            "No TIDAL_MIRROR_URL configured. Set TIDAL_MIRROR_URL (and optionally "
            "ANTRA_API_KEY) in your .env, or ensure the endpoint manifest is reachable."
        )
    return url


def resolve_mirror_key(cfg) -> str:
    key = (getattr(cfg, "antra_api_key", "") or "").strip()
    if key:
        return key
    try:
        manifest = load_endpoint_manifest()
        key = (getattr(manifest, "api_key", "") or "").strip()
    except Exception:
        key = ""
    return key


def make_headers(api_key: str) -> dict:
    return {"X-API-Key": api_key} if api_key else {}


def fetch_track_meta(track_id: str, base: str, headers: dict) -> dict:
    """Fetch a single track's metadata from the mirror (meta endpoint, track fallback)."""
    r = requests.get(f"{base}/api/meta/track/{track_id}", headers=headers, timeout=(15, 120))
    if r.status_code == 200:
        data = r.json()
    else:
        rb = requests.get(f"{base}/api/track/{track_id}", headers=headers, timeout=(15, 120))
        if rb.status_code != 200:
            raise RuntimeError(
                f"Could not fetch track {track_id} from mirror "
                f"(meta={r.status_code}, track={rb.status_code})."
            )
        data = rb.json()
    if not isinstance(data, dict):
        raise RuntimeError(f"Unexpected response for track {track_id}: {str(data)[:200]}")
    if data.get("error") or data.get("status") == "error":
        raise RuntimeError(f"Mirror error for track {track_id}: {data.get('error') or data.get('message', 'unknown')}")
    if not data.get("title") and not data.get("id"):
        raise RuntimeError(f"Could not recognize track {track_id} — no usable metadata returned.")
    return data


def fetch_album(album_id: str, base: str, headers: dict) -> dict:
    """Fetch an album (with its tracks) from the mirror's /api/album endpoint."""
    r = requests.get(f"{base}/api/album/{album_id}", headers=headers, timeout=(15, 120))
    if r.status_code == 404:
        raise RuntimeError(f"Album {album_id} not found on Tidal.")
    if not r.ok:
        raise RuntimeError(f"Could not fetch album {album_id} from mirror (HTTP {r.status_code}).")
    data = r.json()
    if not isinstance(data, dict):
        raise RuntimeError(f"Unexpected response for album {album_id}: {str(data)[:200]}")
    if data.get("error") or data.get("status") == "error":
        raise RuntimeError(f"Mirror error for album {album_id}: {data.get('error') or data.get('message', 'unknown')}")
    return data


def track_from_album_item(item: dict, album_data: dict) -> dict:
    """Normalize an album track item into the same shape as a single-track response."""
    raw_artists = item.get("artists") or []
    artists = [a if isinstance(a, str) else a.get("name", "") for a in raw_artists]
    if not artists:
        artist = item.get("artist") or {}
        name = artist.get("name", "") if isinstance(artist, dict) else ""
        if name:
            artists = [name]
    raw_tid = item.get("track_id") or item.get("id")
    return {
        "id": str(raw_tid) if raw_tid else None,
        "title": item.get("title") or "",
        "artists": [a for a in artists if a],
        "album": item.get("album") or {
            "id": album_data.get("album_id"),
            "title": album_data.get("title") or "",
            "cover": album_data.get("artwork_url") or album_data.get("cover"),
        },
        "album_title": album_data.get("title") or "",
        "artist": item.get("artist"),
        "album_artists": album_data.get("album_artists") or [],
        "artwork_url": album_data.get("artwork_url"),
        "release_date": album_data.get("release_date") or album_data.get("releaseDate"),
        "duration": (item.get("duration_ms") or 0) / 1000 if item.get("duration_ms") else item.get("duration"),
        "duration_ms": item.get("duration_ms"),
        "isrc": item.get("isrc"),
        "track_number": item.get("track_number"),
        "disc_number": item.get("disc_number"),
        "explicit": item.get("explicit"),
    }


def _track_id_of(data: dict) -> str:
    """Best-effort track id from mirror response (several key shapes)."""
    for key in ("id", "track_id", "trackId", "tid"):
        val = data.get(key)
        if val is not None:
            return str(val)
    return ""


def build_result(data: dict, track_id: str) -> SearchResult:
    """Build a SearchResult so TidalMirrorAdapter.download() can stream it."""
    album = data.get("album") or {}
    artists = data.get("artists") or (data.get("artists") or [])
    duration_ms = data.get("duration_ms")
    if duration_ms is None and data.get("duration"):
        duration_ms = int(data["duration"] * 1000)
    return SearchResult(
        source="tidal_mirror",
        title=data.get("title") or "",
        artists=[a for a in artists if a],
        album=(album.get("title") if isinstance(album, dict) else None) or data.get("album_title") or "",
        duration_ms=duration_ms,
        audio_format=AudioFormat.FLAC,
        quality_kbps=None,
        is_lossless=True,
        download_url=None,
        stream_id=str(track_id or _track_id_of(data)),
        similarity_score=1.0,
        isrc_match=True,
        artwork_url=data.get("artwork_url"),
        is_explicit=data.get("explicit"),
    )


def sanitize(name: str, replace: str = " ") -> str:
    return re.sub(r'[\\/:*?"<>|]', replace, name or "").strip() or "Unknown"


class Downloader:
    def __init__(self, adapter, out_dir: str):
        self.adapter = adapter
        self.out_dir = out_dir

    def download_track(self, meta: dict, quiet: bool = False) -> str:
        result = build_result(meta, _track_id_of(meta))
        title = result.title or meta.get("id")
        artist = ", ".join(result.artists) or "Unknown Artist"
        album = result.album or "Unknown Album"

        if not result.is_lossless and not quiet:
            print(f"    (source is lossy: {result.quality_label})")

        folder = sanitize(f"{artist} - {album}")
        track_dir = os.path.join(self.out_dir, folder)
        os.makedirs(track_dir, exist_ok=True)
        output_base = os.path.join(track_dir, sanitize(f"{album}_{title}", "_"))

        final_path = self.adapter.download(result, output_base)
        return final_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Recognize and download Tidal track(s) or an album by ID.")
    parser.add_argument("--id", help="Tidal track/album ID or tidal.com/track|album/… URL")
    parser.add_argument("--kind", choices=("track", "album"), help="Force ID kind (default: track for bare numbers)")
    parser.add_argument("--out", help="Override output directory")
    args = parser.parse_args()

    cfg = load_config()
    default_kind = args.kind or "track"

    try:
        mirror = resolve_mirror(cfg)
        api_key = resolve_mirror_key(cfg)
    except RuntimeError as e:
        print(f"[!] {e}", file=sys.stderr)
        return 1

    adapter = TidalMirrorAdapter(
        mirror_url=mirror,
        api_key=api_key,
        preferred_output_format=getattr(cfg, "output_format", "flac"),
    )
    if not adapter.is_available():
        print(f"[!] Tidal mirror unreachable at {mirror}", file=sys.stderr)
        return 1

    raw_input = args.id
    if not raw_input:
        raw_input = input("Enter Tidal track/album ID (or tidal.com URL): ").strip()

    try:
        kind, item_id = extract_kind_id(raw_input)
    except ValueError as e:
        print(f"[!] {e}", file=sys.stderr)
        return 1

    # Bare numeric IDs — respect a forced --kind, else default to track.
    if raw_input.strip().isdigit():
        kind = default_kind

    headers = make_headers(api_key)

    out_dir = args.out or getattr(cfg, "output_dir", "") or ""
    if out_dir == ".":
        out_dir = ""
    if not out_dir:
        out_dir = os.path.join(os.path.expanduser("~"), "Music")
    out_dir = os.path.abspath(os.path.expanduser(out_dir))

    if kind == "album":
        print(f"[*] Fetching Tidal album {item_id}…")
        try:
            album = fetch_album(item_id, mirror, headers)
        except RuntimeError as e:
            print(f"[!] {e}", file=sys.stderr)
            return 1
        tracks_raw = album.get("tracks") or []
        track_list = []
        for idx, item in enumerate(tracks_raw, 1):
            meta = track_from_album_item(item, album)
            if not meta.get("id"):
                continue
            meta["track_number"] = meta.get("track_number") or idx
            track_list.append(meta)
        if not track_list:
            print("[!] Album returned no usable tracks.", file=sys.stderr)
            return 1

        album_title = album.get("title") or "Unknown Album"
        album_artists = album.get("album_artists") or []
        print(f"[✓] Recognized album: {album_title} — {', '.join(album_artists) or 'Unknown Artist'} ({len(track_list)} tracks)")

        confirm = input(f"Download {len(track_list)} tracks to '{out_dir}'? [Y/n]: ").strip().lower()
        if confirm not in ("", "y", "yes"):
            print("Aborted.")
            return 0

        dl = Downloader(adapter, out_dir)
        saved = []
        failed = 0
        for i, meta in enumerate(track_list, 1):
            name = meta.get("title") or meta.get("id")
            artist = ", ".join(meta.get("artists") or []) or "Unknown Artist"
            print(f"  [{i}/{len(track_list)}] {name} — {artist}")
            try:
                path = dl.download_track(meta)
                saved.append(path)
                print(f"    [✓] {path}")
            except Exception as e:
                failed += 1
                print(f"    [!] Failed: {e}", file=sys.stderr)
        print(f"\n[✓] Downloaded {len(saved)}/{len(track_list)} track(s) → {out_dir}")
        if failed:
            print(f"[!] {failed} track(s) failed.")
        return 0 if failed == 0 else 1

    # Track path
    print(f"[*] Recognizing Tidal track {item_id}…")
    try:
        meta = fetch_track_meta(item_id, mirror, headers)
    except RuntimeError as e:
        print(f"[!] {e}", file=sys.stderr)
        return 1

    result = build_result(meta, item_id)
    title = result.title or item_id
    artist = ", ".join(result.artists) or "Unknown Artist"
    album = result.album or "Unknown Album"
    print(f"[✓] Recognized: {title} — {artist}")
    print(f"    Album: {album} | {result.quality_label}")

    confirm = input(f"Download to '{out_dir}'? [Y/n]: ").strip().lower()
    if confirm not in ("", "y", "yes"):
        print("Aborted.")
        return 0

    print(f"[*] Downloading {title}…")
    try:
        dl = Downloader(adapter, out_dir)
        final_path = dl.download_track(meta)
    except Exception as e:
        print(f"[!] Download failed: {e}", file=sys.stderr)
        return 1

    print(f"[✓] Saved: {final_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())