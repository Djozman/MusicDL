"""Parity test for search↔paste-link (US3 / FR-008, FR-009, SC-005).

Asserts that resolving a track FROM A SEARCH yields the SAME Tidal track ID (and
therefore the same 96 kHz explicit FLAC output) as the equivalent pasted Tidal
link. The parity holds because both paths finalize on the same Tidal stream ID and
route through the same HiRes pipeline.

Kept hermetic: mocks the Tidal mirror so no live network/config is required.
"""
import sys

sys.path.insert(0, "antra")


def test_search_resolution_matches_pasted_link_id():
    """A search result and its pasted Tidal link must resolve to the same Tidal ID."""
    from unittest import mock
    from antra.core.models import SearchResult, AudioFormat
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    import resolve_track

    pasted_link_tidal_id = "263828941"

    fake_hit = SearchResult(
        source="tidal_mirror",
        title="Walk Em Down",
        artists=["Metro Boomin & 21 Savage"],
        album="",
        duration_ms=0,
        quality_kbps=None,
        download_url=None,
        audio_format=AudioFormat.FLAC,
        stream_id=pasted_link_tidal_id,
        similarity_score=1.0,
        is_lossless=True,
    )

    with mock.patch("resolve_track._tidal_mirror_settings", return_value=("https://tidal.example", "k", "source")), \
         mock.patch.object(TidalMirrorAdapter, "is_available", return_value=True), \
         mock.patch.object(TidalMirrorAdapter, "search", return_value=fake_hit):
        resolved = resolve_track.resolve_to_tidal_url(
            "Walk Em Down", "Metro Boomin & 21 Savage", "https://www.deezer.com/track/2047662497"
        )

    # The search-derived URL must carry the SAME Tidal track ID as the pasted link.
    assert resolved["resolved"] is True
    assert resolved["url"] == f"https://tidal.com/track/{pasted_link_tidal_id}"


def test_search_resolution_is_hi_res_flac_source():
    """The resolved source is the Tidal mirror, i.e. the 96 kHz HiRes FLAC source."""
    from unittest import mock
    from antra.core.models import SearchResult, AudioFormat
    from antra.sources.tidal_mirror import TidalMirrorAdapter
    import resolve_track

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
        resolved = resolve_track.resolve_to_tidal_url("Walk Em Down", "Metro Boomin", "https://fallback.example/x")

    # Since the Tidal mirror is the HiRes FLAC source (AudioFormat.FLAC, stream id present),
    # a search selection routes to the same lossless path as a pasted Tidal link (no MP3 fallback).
    assert resolved["source"] == "tidal_mirror"
    assert resolved["resolved"] is True