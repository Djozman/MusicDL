#!/usr/bin/env python3
"""Preview metadata for a music URL using the antra backend, without downloading.

Prints a single JSON line with { title, artist, album, artwork_url,
artists_string, release_date, track_count, tracks: [...] }.

Usage: python3 preview.py <music-url>
"""
import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"type": "error", "message": "No URL provided"}), flush=True)
        return 2

    url = sys.argv[1]

    try:
        from antra.core.config import load_config
        from antra.core.service import AntraService, RuntimeOptions

        cfg = load_config()
        service = AntraService(cfg)
        options = RuntimeOptions(
            output_dir=cfg.output_dir,
            source_preference=cfg.source_preference,
            output_format=cfg.output_format,
        )

        tracks = service.fetch_playlist_tracks(url, options=options, enrich_override=False)

        if not tracks:
            print(json.dumps({"type": "error", "message": "No tracks found for this link"}), flush=True)
            return 1

        # For a single track, surface the actual song title/artist (not the album).
        # For albums/playlists, prefer the release/playlist title.
        if len(tracks) == 1:
            only = tracks[0]
            title = getattr(only, "title", None) or getattr(only, "album", None) or ""
            artist = getattr(only, "artist_string", None) or (
                ", ".join(getattr(only, "artists", []) or [])
            ) or ""
            album = getattr(only, "album", None) or ""
        else:
            first = tracks[0]
            title = (
                getattr(first, "playlist_name", None)
                or getattr(first, "album", None)
                or ""
            )
            artist = (
                getattr(first, "artists_string", None)
                or (", ".join(getattr(first, "artists", []) or []))
                or ""
            )
            album = getattr(first, "album", None) or ""

        artwork = (
            getattr(tracks[0], "playlist_artwork_url", None)
            or getattr(tracks[0], "artwork_url", None)
            or ""
        )
        source = getattr(tracks[0], "source_service", None) or ""

        payload = {
            "type": "preview",
            "title": title,
            "artist": artist,
            "album": album,
            "artwork_url": artwork,
            "source": source,
            "release_date": "",
            "track_count": len(tracks),
            "tracks": [
                {
                    "artist": t.artist_string,
                    "title": t.title,
                    "duration_ms": t.duration_ms or 0,
                }
                for t in tracks
            ],
        }
        print(json.dumps(payload), flush=True)
        return 0

    except Exception as e:  # noqa: BLE001
        print(json.dumps({"type": "error", "message": str(e)}), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())