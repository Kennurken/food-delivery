"""Bring a whole menu in at once, from rows copied out of a spreadsheet.

A restaurant's menu already lives somewhere — Excel, Google Sheets, a POS
export. Typing a hundred dishes into a phone one by one is where onboarding
dies. So the owner copies the rows and pastes them: spreadsheets put tabs
between cells when copied, CSV files use commas or semicolons, and a first row
of headers (in Russian, Kazakh or English) may say which column is which.
Without headers the order is name, price, category, description, photo URL.

Nothing is written until the owner has seen the preview. A dish whose name is
already on the menu is updated rather than duplicated, so pasting a corrected
price list twice is harmless.
"""

from __future__ import annotations

import csv
import io
import re
from dataclasses import asdict, dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.restaurant import MenuItem

MAX_ROWS = 500
MAX_PRICE = 10_000_000
DEFAULT_CATEGORY = "Меню"

_HEADERS = {
    "name": ("название", "наименование", "блюдо", "name", "dish", "item", "атауы", "тағам"),
    "price": ("цена", "стоимость", "price", "cost", "баға", "бағасы"),
    "category": ("категория", "раздел", "category", "section", "санат", "бөлім"),
    "description": ("описание", "состав", "description", "сипаттама", "құрамы"),
    "image_url": ("фото", "картинка", "изображение", "image", "image_url", "photo", "сурет"),
}
_DEFAULT_ORDER = ("name", "price", "category", "description", "image_url")
_CURRENCY = re.compile(r"(₸|тг\.?|тенге|kzt|tg)", re.IGNORECASE)


@dataclass
class Row:
    line: int
    name: str = ""
    price: float | None = None
    category: str = ""
    description: str = ""
    image_url: str | None = None
    action: str = "create"  # create | update | error
    error: str | None = None  # no_name | bad_price | name_too_long | too_many_rows


def _delimiter(text: str) -> str:
    sample = "\n".join(text.splitlines()[:20])
    if "\t" in sample:
        return "\t"
    if ";" in sample:
        return ";"
    return ","


def _price(raw: str) -> float | None:
    cleaned = _CURRENCY.sub("", raw).replace(" ", "").replace(" ", "").replace(",", ".")
    try:
        value = float(cleaned)
    except ValueError:
        return None
    return value if 0 < value < MAX_PRICE else None


def _columns(cells: list[str]) -> dict[str, int] | None:
    """Column positions from a header row, or None if this row is data."""
    found: dict[str, int] = {}
    for i, cell in enumerate(cells):
        label = cell.strip().lower()
        for field, names in _HEADERS.items():
            if field not in found and label in names:
                found[field] = i
    return found if "name" in found and "price" in found else None


def parse(text: str) -> list[Row]:
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines:
        return []
    reader = list(csv.reader(io.StringIO("\n".join(lines)), delimiter=_delimiter(text)))
    columns = _columns(reader[0])
    start = 1 if columns else 0
    columns = columns or {field: i for i, field in enumerate(_DEFAULT_ORDER)}

    rows: list[Row] = []
    for n, cells in enumerate(reader[start:], start=start + 1):

        def cell(field: str, cells: list[str] = cells) -> str:
            i = columns.get(field)
            return cells[i].strip() if i is not None and i < len(cells) else ""

        row = Row(line=n)
        if len(rows) >= MAX_ROWS:
            row.action, row.error = "error", "too_many_rows"
            rows.append(row)
            break
        row.name = cell("name")
        row.price = _price(cell("price"))
        row.category = cell("category")[:50] or DEFAULT_CATEGORY
        row.description = cell("description")[:2000]
        url = cell("image_url")
        row.image_url = url if url.startswith(("https://", "http://")) and len(url) <= 500 else None
        if not row.name:
            row.action, row.error = "error", "no_name"
        elif len(row.name) > 150:
            row.action, row.error = "error", "name_too_long"
        elif row.price is None:
            row.action, row.error = "error", "bad_price"
        rows.append(row)
    return rows


def _key(name: str) -> str:
    return " ".join(name.lower().split())


def run(db: Session, restaurant_id: int, text: str, *, apply: bool) -> dict:
    rows = parse(text)
    existing = {
        _key(item.name): item
        for item in db.scalars(select(MenuItem).where(MenuItem.restaurant_id == restaurant_id))
    }
    seen: set[str] = set()
    created = updated = 0
    for row in rows:
        if row.error:
            continue
        key = _key(row.name)
        # The same dish twice in one paste: the later line wins, once.
        row.action = "update" if key in existing or key in seen else "create"
        seen.add(key)
        if not apply:
            continue
        item = existing.get(key)
        if item is None:
            item = MenuItem(restaurant_id=restaurant_id, name=row.name, price=row.price)
            db.add(item)
            existing[key] = item
            created += 1
        else:
            updated += 1
        item.price = row.price
        item.category = row.category
        if row.description:
            item.description = row.description
        if row.image_url:
            item.image_url = row.image_url
    if apply:
        db.commit()
    else:
        created = sum(1 for r in rows if r.action == "create")
        updated = sum(1 for r in rows if r.action == "update")
    return {
        "applied": apply,
        "created": created,
        "updated": updated,
        "errors": sum(1 for r in rows if r.error),
        "rows": [asdict(r) for r in rows],
    }
