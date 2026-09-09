"""Contract test for the resolve_track.py output shape.

Asserts that ``resolve_track.py <title> <artist> [fallback_url]`` emits a
``{"type": "resolve", ...}`` JSON line with the fields the frontend consumes, and
that a successful Tidal match returns a ``tidal.com/track/<id>`` URL. Kept
hermetic: exercises the resolution helper with a mocked Tidal mirror adapter
rather than requiring a live mirror.
"""
import json
import sys

sys.path.insert(0, "antra")


def test_resolve_success_returns_tidal_url(capfd):
    """A successful Tidal match returns a tidal.com/track/<id> URL."""
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    from antra.core.models import SearchResult, AudioFormat
    from unittest import mock

    fake_hit = SearchResult(
        source="tidal_mirror",
        title="Walk Em Down",
        artists=["Metro Boomin & 21 Savage"],
        album="",
        duration_ms=0,
        quality_kbps=None,
        download_url=None,
        audio_format=AudioFormat.FLAC,
        stream_id="263828941",
        similarity_score=1.0,
        is_lossless=True,
    )

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("https://tidal.example", "k", "source")), \
         mock.patch.object(TidalMirrorAdapter, "is_available", return_value=True), \
         mock.patch.object(TidalMirrorAdapter, "search", return_value=fake_hit):
        import resolve_track
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin & 21 Savage", "https://www.deezer.com/track/2047662497")

    assert resolved["resolved"] is True
    assert resolved["url"] == "https://tidal.com/track/263828941"
    assert resolved["source"] == "tidal_mirror"