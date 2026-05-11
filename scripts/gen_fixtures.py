#!/usr/bin/env python3
"""Regenerate binary test fixtures under backend/tests/fixtures/."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).parent.parent


def _png(path: Path, width: int, height: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    def chunk(tag: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw_rows = b"".join(b"\x00" + b"\xff\xcc\x99" * width for _ in range(height))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw_rows))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)
    print(f"  wrote {path.relative_to(ROOT)}  ({len(png)} bytes)")


def main() -> None:
    base = ROOT / "backend" / "tests" / "fixtures" / "paired_4x"
    print("Generating paired_4x fixture (16×16 HR / 4×4 LR, scale 4)…")
    _png(base / "HR" / "frame_001.png", 16, 16)
    _png(base / "LR" / "frame_001.png", 4, 4)
    print("Done.")


if __name__ == "__main__":
    main()
