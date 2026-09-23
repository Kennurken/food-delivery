"""URL slugs for public pages.

A restaurant page lives at `/r/<slug>/`, so the slug is part of the address bar,
the sitemap and every link anyone shares. That makes it a stored value, not a
derived one: renaming "Bao Bar" to "Bao Bar Almaty" must not silently break
links that are already out in the world.
"""

from __future__ import annotations

import re

from sqlalchemy import select
from sqlalchemy.orm import Session

# Cyrillic is the common case here, and Google reads a Latin slug far better
# than a percent-encoded one.
_CYRILLIC = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
    "ж": "zh", "з": "z", "и": "i", "й": "i", "к": "k", "л": "l", "м": "m",
    "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch",
    "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    # Kazakh letters the Russian table does not cover.
    "ә": "a", "ғ": "g", "қ": "q", "ң": "ng", "ө": "o", "ұ": "u", "ү": "u",
    "һ": "h", "і": "i",
}

MAX_LENGTH = 60


def slugify(value: str) -> str:
    text = "".join(_CYRILLIC.get(ch, ch) for ch in value.strip().lower())
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text[:MAX_LENGTH].strip("-")


def unique_slug(db: Session, model, value: str, *, skip_id: int | None = None) -> str:
    """A slug nothing else is using. Collisions get -2, -3, … rather than a hash:
    a human should still be able to read the URL out loud."""
    base = slugify(value) or "place"
    candidate = base
    suffix = 1
    while True:
        stmt = select(model.id).where(model.slug == candidate)
        if skip_id is not None:
            stmt = stmt.where(model.id != skip_id)
        if db.scalar(stmt) is None:
            return candidate
        suffix += 1
        tail = f"-{suffix}"
        candidate = f"{base[: MAX_LENGTH - len(tail)].strip('-')}{tail}"
