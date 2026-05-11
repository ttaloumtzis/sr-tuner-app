from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

from .errors import ApiError


@dataclass(frozen=True)
class ImageInfo:
    width: int
    height: int
    mode: str
    bit_depth: int | None


def probe_image(path: Path) -> ImageInfo:
    suffix = path.suffix.lower().lstrip(".")
    data = path.read_bytes()
    if suffix == "png":
        return _probe_png(data)
    if suffix in {"jpg", "jpeg"}:
        return _probe_jpeg(data)
    if suffix == "webp":
        return _probe_webp(data)
    if suffix in {"tif", "tiff"}:
        return _probe_tiff(data)
    raise ApiError(422, "unsupported_image_format", "Unsupported image format.", details={"path": str(path)})


def _probe_png(data: bytes) -> ImageInfo:
    if len(data) < 29 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Invalid PNG header.")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    mode = {
        0: "L",
        2: "RGB",
        3: "P",
        4: "LA",
        6: "RGBA",
    }.get(color_type, "unknown")
    return ImageInfo(width=width, height=height, mode=mode, bit_depth=bit_depth)


def _probe_jpeg(data: bytes) -> ImageInfo:
    if len(data) < 4 or not data.startswith(b"\xff\xd8"):
        raise ValueError("Invalid JPEG header.")
    index = 2
    while index < len(data) - 9:
        if data[index] != 0xFF:
            index += 1
            continue
        marker = data[index + 1]
        index += 2
        if marker in {0xD8, 0xD9}:
            continue
        if index + 2 > len(data):
            break
        length = struct.unpack(">H", data[index : index + 2])[0]
        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
            bit_depth = data[index + 2]
            height, width = struct.unpack(">HH", data[index + 3 : index + 7])
            channels = data[index + 7]
            mode = "L" if channels == 1 else "RGB" if channels == 3 else "unknown"
            return ImageInfo(width=width, height=height, mode=mode, bit_depth=bit_depth)
        index += length
    raise ValueError("JPEG dimensions were not found.")


def _probe_webp(data: bytes) -> ImageInfo:
    if len(data) < 30 or data[0:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise ValueError("Invalid WebP header.")
    chunk = data[12:16]
    if chunk == b"VP8X":
        width = int.from_bytes(data[24:27], "little") + 1
        height = int.from_bytes(data[27:30], "little") + 1
        alpha = bool(data[20] & 0x10)
        return ImageInfo(width=width, height=height, mode="RGBA" if alpha else "RGB", bit_depth=8)
    if chunk == b"VP8 " and len(data) >= 30:
        width = struct.unpack("<H", data[26:28])[0] & 0x3FFF
        height = struct.unpack("<H", data[28:30])[0] & 0x3FFF
        return ImageInfo(width=width, height=height, mode="RGB", bit_depth=8)
    if chunk == b"VP8L" and len(data) >= 25:
        b0, b1, b2, b3 = data[21:25]
        width = 1 + (((b1 & 0x3F) << 8) | b0)
        height = 1 + (((b3 & 0x0F) << 10) | (b2 << 2) | ((b1 & 0xC0) >> 6))
        return ImageInfo(width=width, height=height, mode="RGBA", bit_depth=8)
    raise ValueError("Unsupported WebP header.")


def _probe_tiff(data: bytes) -> ImageInfo:
    if len(data) < 8:
        raise ValueError("Invalid TIFF header.")
    byte_order = data[0:2]
    endian = "<" if byte_order == b"II" else ">" if byte_order == b"MM" else None
    if endian is None or struct.unpack(f"{endian}H", data[2:4])[0] != 42:
        raise ValueError("Invalid TIFF header.")
    offset = struct.unpack(f"{endian}I", data[4:8])[0]
    if offset + 2 > len(data):
        raise ValueError("Invalid TIFF IFD offset.")
    count = struct.unpack(f"{endian}H", data[offset : offset + 2])[0]
    values: dict[int, int] = {}
    for i in range(count):
        entry = offset + 2 + i * 12
        if entry + 12 > len(data):
            break
        tag, field_type, _count, value = struct.unpack(f"{endian}HHII", data[entry : entry + 12])
        if field_type in {3, 4}:
            values[tag] = value & 0xFFFF if field_type == 3 else value
    width = values.get(256)
    height = values.get(257)
    samples = values.get(277, 3)
    bit_depth = values.get(258, 8)
    if not width or not height:
        raise ValueError("TIFF dimensions were not found.")
    mode = "L" if samples == 1 else "RGB" if samples == 3 else "unknown"
    return ImageInfo(width=width, height=height, mode=mode, bit_depth=bit_depth)
