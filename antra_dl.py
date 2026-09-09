"""
antra_dl — tiny CLI that takes a track/album/playlist URL from Spotify, Tidal,
Amazon Music, Qobuz, Deezer, Apple Music, SoundCloud, or YouTube Music,
recognizes the release, and downloads the tracks as lossless FLAC.

It reuses Antra's full pipeline via AntraService:
  - fetch_playlist_tracks()   recognizes the URL across every supported service
  - download_tracks()         resolves each track to the best available source
                              (Tidal/Qobuz mirror → Amazon → Deezer → …) and
                              tags/saves it into the configured output dir.

Usage:
  python antra_dl.py --url "https://open.spotify.com/track/..."
  python antra_dl.py --url "https://tidal.com/album/..."
  python antra_dl.py --url "https://www.amazon.co.uk/dp/B0..."
  python antra_dl.py --url "https://play.qobuz.com/album/..."
  python antra_dl.py --url "https://open.spotify.com/album/..."
  python antra_dl.py --url "..." --out /path/to/Music --format lossless-24
"""
import argparse
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from antra.core.service import AntraService, RuntimeOptions


def resolve_out_dir(args_out: str) -> str:
    out = args_out or os.environ.get("OUTPUT_DIR", "") or ""
    if out and out != ".":
        return os.path.abspath(os.path.expanduser(out))
    return os.path.join(os.path.expanduser("~"), "Music")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download tracks/albums/playlists from Spotify, Tidal, Amazon, "
                    "Qobuz, Deezer, Apple Music, SoundCloud, or YouTube Music."
    )
    parser.add_argument("--url", help="Track/album/playlist URL from a supported service")
    parser.add_argument("--out", help="Override output directory (default: ~/Music)")
    parser.add_argument(
        "--format",
        choices=("source", "flac", "alac", "m4a", "aac", "mp3",
                 "lossless-16", "lossless-24", "alac-16", "alac-24"),
        help="Output format (default: from config / env OUTPUT_FORMAT)",
    )
    parser.add_argument(
        "--yes", "-y", action="store_true",
        help="Skip the confirmation prompt",
    )
    args = parser.parse_args()

    url = args.url
    if not url:
        url = input("Enter a track/album/playlist URL: ").strip()
    if not url:
        print("[!] No URL provided.", file=sys.stderr)
        return 1

    out_dir = resolve_out_dir(args.out)

    options = RuntimeOptions(output_dir=out_dir)
    if args.format:
        options.output_format = args.format

    service = AntraService()
    print(f"[*] Fetching: {url}")
    try:
        tracks = service.fetch_playlist_tracks(url, options=options)
    except Exception as e:
        print(f"[!] Could not recognize URL: {e}", file=sys.stderr)
        return 1

    if not tracks:
        print("[!] No tracks found for that URL.", file=sys.stderr)
        return 1

    shown = tracks[:5]
    print(f"[✓] Recognized {len(tracks)} track(s):")
    for i, t in enumerate(shown, 1):
        print(f"    {i}. {t.title} — {t.primary_artist}")
    if len(tracks) > 5:
        print(f"    … and {len(tracks) - 5} more")

    if not args.yes:
        confirm = input(f"Download {len(tracks)} track(s) to '{out_dir}'? [Y/n]: ").strip().lower()
        if confirm not in ("", "y", "yes"):
            print("Aborted.")
            return 0

    print(f"[*] Downloading {len(tracks)} track(s) to {out_dir} …")

    def on_event(event):
        name = event.event_type.value if hasattr(event, "event_type") else ""
        if "completed" in name:
            print(f"    [✓] {getattr(event, 'track', '') and getattr(event.track, 'title', '') or ''}")

    results = service.download_tracks(tracks, options=options, event_callback=on_event)

    ok = [r for r in results if r.status.value in ("completed", "skipped")]
    fail = [r for r in results if r.status.value == "failed"]
    print(f"\n[✓] Done: {len(ok)}/{len(results)} track(s) → {out_dir}")
    if fail:
        print(f"[!] {len(fail)} track(s) failed:")
        for r in fail:
            print(f"    - {getattr(r.track, 'title', '')}: {r.error_message or 'unknown error'}")
    return 0 if not fail else 1


if __name__ == "__main__":
    raise SystemExit(main())