"""Unit tests for the public (unauthenticated) Deezer search source."""
from unittest import mock

from antra.sources.deezer_public import _is_explicit, search_deezer


def test_is_explicit_from_lyrics_flag():
    assert _is_explicit({"explicit_lyrics": True}) is True
    assert _is_explicit({"explicit_lyrics": False}) is False
    assert _is_explicit({}) is False


def test_is_explicit_from_content_lyrics():
    assert _is_explicit({"explicit_lyrics": False, "explicit_content_lyrics": 1}) is True
    assert _is_explicit({"explicit_lyrics": False, "explicit_content_lyrics": 6}) is True
    assert _is_explicit({"explicit_lyrics": False, "explicit_content_lyrics": 0}) is False


@mock.patch("requests.get")
def test_search_deezer_normalizes_results(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.raise_for_status = lambda: None
    mock_get.return_value.json.return_value = {
        "data": [
            {
                "id": 2047662497,
                "title": "Walk Em Down (Don't Kill Civilians)",
                "readable": True,
                "explicit_lyrics": True,
                "artist": {"name": "Metro Boomin"},
                "album": {"title": "HEROES & VILLAINS", "cover_xl": "http://img/xl.jpg"},
                "duration": 311,
            }
        ]
    }
    results = search_deezer("walk em down")
    assert len(results) == 1
    r = results[0]
    assert r["type"] == "track"
    assert r["source"] == "deezer"
    assert r["is_explicit"] is True
    assert r["track_url"] == "https://www.deezer.com/track/2047662497"
    assert r["artwork_url"] == "http://img/xl.jpg"
    assert r["artist"] == "Metro Boomin"


@mock.patch("requests.get")
def test_search_deezer_skips_unreadable(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.raise_for_status = lambda: None
    mock_get.return_value.json.return_value = {
        "data": [
            {"id": 1, "title": "A", "readable": False, "explicit_lyrics": False,
             "artist": {"name": "X"}, "album": {"title": "Y"}},
        ]
    }
    assert search_deezer("q") == []


@mock.patch("requests.get")
def test_search_deezer_handles_api_error(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.raise_for_status = lambda: None
    mock_get.return_value.json.return_value = {"error": {"type": "DataException"}}
    assert search_deezer("q") == []


@mock.patch("requests.get")
def test_search_deezer_handles_network_error(mock_get):
    mock_get.side_effect = Exception("boom")
    assert search_deezer("q") == []