"""Unit tests for best-effort search refinement helpers."""
import pytest

from antra.utils.search_refine import (
    is_derivative,
    infer_explicit_from_title,
    dedupe_editions,
    refine_itunes_results,
)


def test_is_derivative_flags_filler():
    assert is_derivative({"title": "God's Plan", "album": "KIDZ BOP Kids"})
    assert is_derivative({"title": "Humble", "album": "Karaoke Hits"})
    assert is_derivative({"title": "God's Plan", "album": "Lullaby Versions"})
    assert is_derivative({"title": "HUMBLE. (Originally Performed by K)", "album": "Y"})


def test_is_derivative_does_not_flag_official_live_remix():
    # Legitimate official/live/remix/instrumental releases are preserved.
    assert not is_derivative({"title": "SICKO MODE", "album": "ASTROWORLD"})
    assert not is_derivative({"title": "HUMBLE.", "album": "DAMN."})
    assert not is_derivative({"title": "Mask Off (Instrumental)", "album": "Radio Hits"})
    assert not is_derivative({"title": "SICKO MODE (Guy Arthur Remix)", "album": "ASTROWORLD"})


def test_infer_explicit_from_title():
    assert infer_explicit_from_title("Num (Explicit)", None) is True
    assert infer_explicit_from_title("Num [Explicit]", False) is True
    assert infer_explicit_from_title("Num (Clean Edition)", None) is False
    assert infer_explicit_from_title("Num (Radio Edit)", None) is False
    assert infer_explicit_from_title("Num (feat. X)", None) is None


def test_infer_explicit_keeps_known_flag():
    # No title marker -> keep the provider flag as-is.
    assert infer_explicit_from_title("Mask Off", False) is False
    assert infer_explicit_from_title("Mask Off", True) is True


def test_dedupe_editions_collapses_same_track():
    results = [
        {"title": "Mask Off", "artist": "Future", "is_explicit": False},
        {"title": "Mask Off", "artist": "Future", "is_explicit": False},
        {"title": "Mask Off (Remix) [feat. Kendrick Lamar]", "artist": "Future", "is_explicit": False},
    ]
    deduped = dedupe_editions(results)
    assert len(deduped) < len(results)


def test_dedupe_keeps_different_artists_separate():
    # Same base title but different artists must NOT be merged.
    results = [
        {"title": "Walk Em Down", "artist": "21 Savage & Metro Boomin"},
        {"title": "Walk Em Down (feat. Roddy Ricch)", "artist": "NLE Choppa"},
    ]
    deduped = dedupe_editions(results)
    assert len(deduped) == 2


def test_dedupe_prefers_explicit_title_marker():
    results = [
        {"title": "Mask Off (Clean)", "artist": "Future", "is_explicit": False},
        {"title": "Mask Off (Explicit)", "artist": "Future", "is_explicit": False},
    ]
    deduped = dedupe_editions(results)
    assert "Explicit" in deduped[0]["title"]


def test_refine_itunes_results_end_to_end():
    raw = [
        {"title": "God's Plan", "album": "KIDZ BOP Kids", "artist": "KIDZ BOP Kids", "is_explicit": None},
        {"title": "Mask Off", "album": "FUTURE", "artist": "Future", "is_explicit": False},
        {"title": "Mask Off (Remix) [feat. Kendrick Lamar]", "album": "FUTURE", "artist": "Future", "is_explicit": False},
        {"title": "Mask Off (Explicit)", "album": "FUTURE", "artist": "Future", "is_explicit": False},
    ]
    refined = refine_itunes_results(raw)
    # Filler kids' cover is dropped; FUTURE editions collapse to one, preferring
    # the explicit-marker variant.
    titles = [r["title"] for r in refined]
    assert all("KIDZ" not in r["title"] and "KIDZ" not in (r.get("album") or "") for r in refined)
    assert any("Explicit" in t for t in titles)
    assert len(refined) <= 2