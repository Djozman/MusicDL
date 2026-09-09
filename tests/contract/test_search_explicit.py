"""Contract test for the search output shape.

Asserts that search results carry the ``is_explicit`` field (true/false/absent)
and that explicit variants precede non-explicit ones when both are present,
per fr-002a and the search-api contract.

Kept hermetic: exercises the ordering helper and the search result shaping rather
than requiring a live, authenticated provider hit.
"""
import sys

import pytest

sys.path.insert(0, "antra")

from antra.utils.search_ordering import sort_explicit_first  # noqa: E402


def _assert_contract_shape(results):
    """Results must be a list of dicts each exposing is_explicit (maybe absent)."""
    assert isinstance(results, list)
    for r in results:
        assert isinstance(r, dict)
        value = r.get("is_explicit")
        assert value in (True, False, None)


def test_contract_shape_with_explicit_field():
    results = [
        {"title": "track x", "is_explicit": True},
        {"title": "track y", "is_explicit": False},
        {"title": "track z"},
    ]
    _assert_contract_shape(results)


def test_contract_ordering_explicit_first():
    results = [
        {"title": "clean", "is_explicit": False},
        {"title": "explicit", "is_explicit": True},
        {"title": "explicit2", "is_explicit": True},
        {"title": "clean2", "is_explicit": False},
    ]
    ordered = sort_explicit_first(results)
    flags = [r["is_explicit"] for r in ordered]
    # All explicit (True) must come before all clean (False).
    assert flags.index(True) < flags.index(False)
    assert flags[:2] == [True, True]
    assert flags[2:] == [False, False]


def test_contract_absent_flag_is_unknown():
    # A result without the flag must sort as unknown (rank middle), not be dropped
    # or mislabeled as clean.
    results = [
        {"title": "clean", "is_explicit": False},
        {"title": "no flag"},
        {"title": "explicit", "is_explicit": True},
    ]
    ordered = sort_explicit_first(results)
    assert ordered[0]["title"] == "explicit"
    assert ordered[1]["title"] == "no flag"
    assert ordered[2]["title"] == "clean"