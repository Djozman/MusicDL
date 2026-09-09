"""Unit tests for the explicit-first ordering helper.

Covers FR-002a: explicit variants sort first, clean variants last, and unknown
status sorts in the middle. Includes the default dict extraction and a custom key.
"""
import pytest

from antra.utils.search_ordering import sort_explicit_first
from antra.core.spotify import _itunes_explicit


def test_explicit_true_sorts_first():
    results = [
        {"title": "clean", "is_explicit": False},
        {"title": "explicit", "is_explicit": True},
        {"title": "clean2", "is_explicit": False},
        {"title": "explicit2", "is_explicit": True},
        {"title": "unknown", "is_explicit": None},
        {"title": "missing_flag"},
    ]
    ordered = sort_explicit_first(results)
    assert ordered[0]["title"] == "explicit"
    assert ordered[1]["title"] == "explicit2"
    # ordered[2] and ordered[3] are both rank 1 (unknown / absent flag).
    assert ordered[2]["title"] in {"unknown", "missing_flag"}
    assert ordered[3]["title"] in {"unknown", "missing_flag"}
    assert ordered[4]["title"] == "clean"
    assert ordered[5]["title"] == "clean2"


def test_extract_flag_camel_case_key():
    items = [
        {"isExplicit": False},
        {"isExplicit": True},
        {},
        {"isExplicit": False},
    ]
    assert sort_explicit_first(items)[0]["isExplicit"] is True


def test_stable_order_within_groups():
    results = [
        {"is_explicit": False, "n": 1},
        {"is_explicit": True, "n": 2},
        {"is_explicit": False, "n": 3},
    ]
    ordered = sort_explicit_first(results, key=lambda x: x.get("is_explicit"))
    assert ordered[0]["n"] == 2
    assert ordered[1]["n"] == 1
    assert ordered[2]["n"] == 3


@pytest.mark.parametrize(
    "track,collection,expected",
    [
        ("explicit", None, True),
        ("Explicit", "cleaned", True),
        ("cleaned", None, False),
        ("notExplicit", None, False),
        ("not explicit", None, False),
        (None, "explicit", True),
        (None, "notExplicit", False),
        (None, None, None),
        ("", "cleaned", False),
    ],
)
def test_itunes_explicit_mapping(track, collection, expected):
    assert _itunes_explicit(track, collection) == expected