#!/usr/bin/env python3
"""Download a music URL, optionally restricted to selected tracks.

Mirrors antra.json_cli's download orchestration but honours a user-selected
subset. The frontend passes the URL plus the 0-based indices of the tracks to
download; the helper fetches full track metadata, filters to the selection, and
streams per-track events the same way json_cli does.

Usage: python3 download.py <music-url> [index index ...]
"""
import json
import os
import sys
import time


def _emit(obj: dict) -> None:
    print(json.dumps(obj), flush=True)


def _parse_args(argv):
    """Parse CLI args, stripping the optional --out override.

    Returns (url, out_dir_override, selected_indices). ``--out`` may appear before or
    after the URL; its value (if any) overrides the config/environment default.
    """
    args = list(argv)
    out_dir_override = ""
    if "--out" in args:
        i = args.index("--out")
        if i + 1 < len(args):
            out_dir_override = args[i + 1]
        del args[i:i + 2]
    if not args:
        return None, "", []
    return args[0], out_dir_override, [int(a) for a in args[1:] if a.isdigit()]


def main() -> int:
    parsed = _parse_args(sys.argv[1:])
    if parsed[0] is None:
        _emit({"type": "log", "level": "error", "message": "No URL provided"})
        return 2

    url, out_dir_override, selected = parsed

    try:
        from antra.core.config import load_config
        from antra.core.service import AntraService, RuntimeOptions
        from antra.utils.organizer import LibraryOrganizer

        cfg = load_config()
        service = AntraService(cfg)
        out_dir = os.path.abspath(os.path.expanduser(out_dir_override)) if out_dir_override else cfg.output_dir
        options = RuntimeOptions(
            output_dir=out_dir,
            source_preference=cfg.source_preference,
            output_format=cfg.output_format
        )

        org_kwargs = dict(
            full_albums=getattr(cfg, "library_mode", "smart_dedup") == "full_albums",
            folder_structure=getattr(cfg, "folder_structure", "standard"),
            album_folder_structure=getattr(cfg, "album_folder_structure", getattr(cfg, "folder_structure", "standard")),
            playlist_folder_structure=getattr(cfg, "playlist_folder_structure", getattr(cfg, "folder_structure", "standard")),
            single_track_structure=getattr(cfg, "single_track_structure", "album_numbered"),
            filename_format=getattr(cfg, "filename_format", "default"),
            single_track_filename_template=getattr(cfg, "single_track_filename_template", ""),
            album_track_filename_template=getattr(cfg, "album_track_filename_template", ""),
            folder_structure_template=getattr(cfg, "folder_structure_template", ""),
            multi_disc_handling=getattr(cfg, "multi_disc_handling", "prefix"),
            track_number_padding=getattr(cfg, "track_number_padding", 2),
            illegal_character_replacement=getattr(cfg, "illegal_character_replacement", ""),
            whitespace_handling=getattr(cfg, "whitespace_handling", "preserve"),
            filename_conflict_behavior=getattr(cfg, "filename_conflict_behavior", "skip"),
        )

        tracks = service.fetch_playlist_tracks(url, options=options, enrich_override=False)
        if not tracks:
            _emit({"type": "log", "level": "error", "message": "No tracks found for this link"})
            return 1

        requested = set(selected) if selected else set(range(len(tracks)))
        to_download = [t for i, t in enumerate(tracks) if i in requested]

        if not to_download:
            _emit({"type": "log", "level": "error", "message": "No tracks selected for download"})
            return 1

        # A pasted single-track link lands directly in the output root as one
        # song file, not inside Artist/Album folders.
        if len(tracks) == 1:
            org_kwargs["single_track_structure"] = "file"
        organizer = LibraryOrganizer(out_dir, **org_kwargs)

        from datetime import datetime
        _url_start = time.time()

        _emit({
            "type": "download_started",
            "url": url,
            "total": len(to_download),
            "selected": sorted(requested),
        })

        to_download = service.enrich_tracks_for_download(to_download, url, options=options)
        results = service.download_tracks(to_download, options=options, event_callback=_emit_engine_event, organizer=organizer)

        from dataclasses import asdict
        _total_bytes = sum(
            getattr(r, "file_path", None) and __import__("os").path.getsize(r.file_path) or 0
            for r in results
            if getattr(r, "file_path", None)
        )

        summary = {
            "type": "download_summary",
            "url": url,
            "total": len(results),
            "downloaded": sum(1 for r in results if r.status.name == "COMPLETED"),
            "failed": sum(1 for r in results if r.status.name == "FAILED"),
            "skipped": sum(1 for r in results if r.status.name == "SKIPPED"),
            "total_mb": round(_total_bytes / (1024 * 1024), 1),
            "elapsed_seconds": round(time.time() - _url_start),
            "date": datetime.now().isoformat(),
        }
        _emit(summary)
        _emit({"type": "done"})
        return 0

    except Exception as e:  # noqa: BLE001
        _emit({"type": "error", "message": str(e), "url": url})
        return 1


def _emit_engine_event(event) -> None:
    """Mirror json_cli.emit_event for per-track progress."""
    track_payload = None
    try:
        from dataclasses import asdict
        if event.track:
            track_payload = asdict(event.track)
            track_payload.pop("lyrics", None)
            track_payload.pop("synced_lyrics", None)
    except Exception:  # noqa: BLE001
        track_payload = None

    _emit({
        "type": "event",
        "name": event.type.value if hasattr(event, "type") else "",
        "payload": {
            "track": event.track.title if event.track else None,
            "artist": event.track.artist_string if event.track else None,
            "track_index": getattr(event, "track_index", None),
            "track_total": getattr(event, "track_total", None),
            "message": getattr(event, "message", None),
            "source": getattr(event, "source", None),
            "error": getattr(event, "error", None),
            "quality_label": getattr(event, "quality_label", None),
            "attempt": getattr(event, "attempt", None),
            "track_data": track_payload,
        },
    })


if __name__ == "__main__":
    sys.exit(main())