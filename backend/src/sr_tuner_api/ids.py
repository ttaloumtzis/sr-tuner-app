from __future__ import annotations

import re
from uuid import uuid4


def new_id(prefix: str) -> str:
    cleaned = slugify(prefix)
    return f"{cleaned}_{uuid4().hex[:16]}"


def slugify(value: str, *, fallback: str = "item") -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.strip().lower())
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug or fallback
