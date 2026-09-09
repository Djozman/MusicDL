"""Unit tests for the Tidal-first resolution logic (FR-010).

Verifies that ``resolve_track.resolve_to_tidal_url`` takes the FIRST title+artist
match from the Tidal mirror with no confirmation step, returns a numeric Tidal
stream ID, and gracefully keeps the fallback URL when the mirror is unconfigured,
unavailable, or returns no match.
"""
import sys

sys.path.insert(0, "antra")


def _hit(stream_id: str):
    from antra.core.models import SearchResult, AudioFormat
    return SearchResult(
        source="tidal_mirror",
        title="Walk Em Down",
        artists=["Metro Boomin & 21 Savage"],
        album="",
        duration_ms=0,
        quality_kbps=None,
        download_url=None,
        audio_format=AudioFormat.FLAC,
        stream_id=stream_id,
        similarity_score=1.0,
        is_lossless=True,
    )


def test_first_match_used_no_confirmation():
    """The first (top-ranked) Tidal match's stream_id is returned directly."""
    from unittest import mock
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    import resolve_track

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("https://tidal.example", "k", "source")), \
         mock.patch.object(TidalMirrorAdapter, "is_available", return_value=True), \
         mock.patch.object(TidalMirrorAdapter, "search", return_value=_hit("263828941")) as search:
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin & 21 Savage", "fallback")

    search.assert_called_once()
    assert resolved["resolved"] is True
    assert resolved["url"] == "https://tidal.com/track/263828941"


def test_no_mirror_keeps_fallback():
    from unittest import mock
    import resolve_track

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("", "k", "source")) as settings:
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin", "https://fallback.example/x")

    settings.assert_called_once()
    assert resolved["resolved"] is False
    assert resolved["url"] == "https://fallback.example/x"


def test_unavailable_mirror_keeps_fallback():
    from unittest import mock
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    import resolve_track

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("https://tidal.example", "k", "source")), \
         mock.patch.object(TidalMirrorAdapter, "is_available", return_value=False), \
         mock.patch.object(TidalMirrorAdapter, "search") as search:
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin", "https://fallback.example/x")

    search.assert_not_called()
    assert resolved["resolved"] is False
    assert resolved["url"] == "https://fallback.example/x"


def test_no_match_keeps_fallback():
    from unittest import mock
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    import resolve_track

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("https://tidal.example", "k", "source")), \
         mock.patch.object(TidalMirrorAdapter, "is_available", return_value=True), \
         mock.patch.object(TidalMirrorAdapter, "search", return_value=None):
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin", "https://fallback.example/x")

    assert resolved["resolved"] is False
    assert resolved["url"] == "https://fallback.example/x"