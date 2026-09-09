"""Stable explicit-first ordering for music search results.

Implements FR-002a: within a set of search results, explicit variants
(``is_explicit == true``) sort above non-explicit variants
(``is_explicit == false``), with unknown status (``None`` / absent) in between.
"""
from typing import Any, Callable, Optional, Sequence


def _explicit_rank(value: Optional[bool]) -> int:
    """Rank for the explicit/clean/unknown ordering key.

    Explicit first (0), unknown middle (1), clean last (2).
    """
    if value is True:
        return 0
    if value is False:
        return 2
    return 1


def _extract_flag(item: Any) -> Optional[bool]:
    """Return the explicit flag from a dict-like item (snake or camel case)."""
    if isinstance(item, dict):
        value = item.get("is_explicit", item.get("isExplicit"))
        return value if isinstance(value, bool) else None
    return None


def sort_explicit_first(
    items: Sequence[Any],
    key: Optional[Callable[[Any], Optional[bool]]] = None,
) -> list:
    """Return ``items`` stably sorted explicit-first.

    ``key`` (optional) returns the raw explicit flag (``bool`` or ``None``) for
    each item; by default the flag is extracted from dict keys ``is_explicit`` /
    ``isExplicit``. ``True`` sorts first, ``None`` middle, ``False`` last.
    """
    flag_fn = key or _extract_flag
    return sorted(items, key=lambda x: _explicit_rank(flag_fn(x)))