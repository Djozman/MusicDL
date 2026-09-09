"""Search-result refinement helpers (best-effort, no auth required).

Helps the public iTunes fallback surface fewer, cleaner results:
  - drop obvious covers, remixes, instrumental-only and tribute filler
  - deduplicate near-identical release editions
  - infer an explicit/clean flag from the track title when the store does not
    (e.g. "(Explicit)" vs "Clean") — used only as a label hint.
"""
import re
from typing import Dict, List, Optional

from antra.utils.matching import normalize, string_similarity


# Markers for clearly-unwanted derivative content that only clutters results:
# children's/cover/tribute re-recordings and karaoke/instrumental backing tracks.
# Deliberately NARROW — does not flag live/remix/edit/acoustic so legitimate
# official releases of the queried artist are not dropped.
_DERIVATIVE_RE = re.compile(
    r"(kidz\s?bop|lullab(?:y|ies)|rockabye|karaoke|tribute|cover|\bvsq\b|"
    r"performs?|original(?: lyric)? authour|sleep\s+(?:baby|music)|"
    r"babies|music\s+box|originally\s+performed|in\s+the\s+style\s+of|8\s?bit)",
    re.IGNORECASE,
)

# Explicit / clean edition markers often present in track titles.
_EXPLICIT_RE = re.compile(r"\(\s*explicit\s*\)|\[\s*explicit\s*\]|\bexplicit\b", re.IGNORECASE)
_CLEAN_MARKER_RE = re.compile(
    r"\(\s*clean(?: edition)?\s*\)|\[\s*clean(?: edition)?\s*\]|\bedited\b"
    r"|\bradio\s+edit\b|\bcensored\b",
    re.IGNORECASE,
)


def is_derivative(item: Dict) -> bool:
    """Best-effort: is this a filler/derivative release better hidden?"""
    title = (item.get("title") or "").lower()
    album = (item.get("album") or "").lower()
    return bool(_DERIVATIVE_RE.search(title) or _DERIVATIVE_RE.search(album))


def infer_explicit_from_title(title: str, explicit: Optional[bool]) -> Optional[bool]:
    """Infer an explicit/clean flag from the title, falling back to ``explicit``.

    Never guesses when there is no signal: returns ``explicit`` unchanged unless a
    clear (Explicit) or Clean marker is present in the title.
    """
    if not title:
        return explicit
    if _EXPLICIT_RE.search(title):
        return True
    if _CLEAN_MARKER_RE.search(title):
        return False
    return explicit


def dedupe_editions(results: List[Dict], title_sim_threshold: float = 0.9) -> List[Dict]:
    """Collapse near-identical releases of the SAME track by the SAME artist.

    Two results are grouped only when both their normalized title AND normalized
    artist are similar, so genuinely different songs (e.g. "Walk Em Down" by
    21 Savage vs. NLE Choppa) are kept separate. Within a group, prefer the version
    with an explicit marker in the title, else the first (store-ranked) entry.
    """
    groups: List[List[Dict]] = []
    for item in results:
        base_title = normalize(item.get("title") or "")
        base_artist = normalize(item.get("artist") or "")
        placed = False
        for group in groups:
            rep = group[0]
            rep_title = normalize(rep.get("title") or "")
            rep_artist = normalize(rep.get("artist") or "")
            if not base_title or not base_artist:
                continue
            same_track = string_similarity(base_title, rep_title) >= title_sim_threshold
            same_artist = string_similarity(base_artist, rep_artist) >= title_sim_threshold
            if same_track and same_artist:
                group.append(item)
                placed = True
                break
        if not placed:
            groups.append([item])

    chosen: List[Dict] = []
    for group in groups:
        # Prefer a version that has an explicit marker in the title, else the
        # store-ranked first entry.
        def rank(it: Dict) -> tuple:
            title = it.get("title") or ""
            has_explicit = 0 if _EXPLICIT_RE.search(title) else 1
            return (has_explicit, 0)

        group.sort(key=rank)
        chosen.append(group[0])
    return chosen


def refine_itunes_results(results: List[Dict]) -> List[Dict]:
    """Apply cleanup to raw iTunes search results.

      1. Drops clearly-filler derivative content (kids' covers, karaoke,
         instrumental-only re-recordings) via the narrow ``is_derivative`` filter.
      2. Infers an explicit/clean flag from the title where present.
      3. Deduplicates exact title+artist editions, preferring an explicit marker.

    Official/live/remix/remaster results by the queried artist are preserved.
    """
    filtered = [r for r in results if not is_derivative(r)]
    for r in filtered:
        r["is_explicit"] = infer_explicit_from_title(
            r.get("title") or "", r.get("is_explicit")
        )
    return dedupe_editions(filtered)