#!/usr/bin/env python3
"""Pack rendered PNG assets into a modern ICNS container."""

from __future__ import annotations

import struct
import sys
from pathlib import Path


CHUNKS = (
    ("icp4", "icon_16x16.png", 16),
    ("icp5", "icon_32x32.png", 32),
    ("icp6", "icon_32x32@2x.png", 64),
    ("ic07", "icon_128x128.png", 128),
    ("ic08", "icon_256x256.png", 256),
    ("ic09", "icon_512x512.png", 512),
    ("ic10", "icon_512x512@2x.png", 1024),
)


def png_dimensions(data: bytes) -> tuple[int, int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("asset is not a PNG with an IHDR chunk")
    return struct.unpack(">II", data[16:24])


def pack(iconset: Path, output: Path) -> None:
    chunks: list[bytes] = []
    for chunk_type, filename, expected_size in CHUNKS:
        data = (iconset / filename).read_bytes()
        dimensions = png_dimensions(data)
        if dimensions != (expected_size, expected_size):
            raise ValueError(
                f"{filename} is {dimensions[0]}x{dimensions[1]}, expected "
                f"{expected_size}x{expected_size}"
            )
        chunks.append(
            chunk_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data
        )

    payload = b"".join(chunks)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: pack_icns.py ICONSET OUTPUT", file=sys.stderr)
        return 2
    pack(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
