"""Contract test for the download.py queue-protocol argument parsing.

Asserts that ``download.py`` accepts an optional ``--out <dir>`` override (needed
for the per-session output-directory feature) before/after the URL and a subset of
track indices, per ``contracts/download-protocol.md``. Exercises the parsing helper
hermetically without spawning a real download.
"""
import os
import sys

sys.path.insert(0, "antra")
sys.path.insert(0, ".")

import download  # noqa: E402


def test_parse_url_only():
    url, out_dir, selected = download._parse_args(["https://tidal.com/album/1"])
    assert url == "https://tidal.com/album/1"
    assert out_dir == ""
    assert selected == []


def test_parse_url_with_indices():
    url, out_dir, selected = download._parse_args(["https://tidal.com/album/1", "0", "2"])
    assert url == "https://tidal.com/album/1"
    assert selected == [0, 2]


def test_parse_out_override_after_url():
    url, out_dir, selected = download._parse_args(
        ["https://tidal.com/album/1", "--out", "/tmp/music"])
    assert url == "https://tidal.com/album/1"
    assert out_dir == "/tmp/music"


def test_parse_out_override_before_url():
    url, out_dir, _ = download._parse_args(
        ["--out", "/tmp/music", "https://tidal.com/album/1"])
    assert url == "https://tidal.com/album/1"
    assert out_dir == "/tmp/music"


def test_parse_out_with_indices():
    url, out_dir, selected = download._parse_args(
        ["https://tidal.com/album/1", "--out", "/tmp/music", "1", "3"])
    assert url == "https://tidal.com/album/1"
    assert out_dir == "/tmp/music"
    assert selected == [1, 3]


def test_parse_no_args_returns_none_url():
    url, out_dir, selected = download._parse_args([])
    assert url is None
    assert out_dir == ""
    assert selected == []