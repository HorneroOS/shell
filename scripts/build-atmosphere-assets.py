#!/usr/bin/env python3
"""Regenerate assets/atmosphere/*.png (deterministic; original work, MIT).

grain.png      128 x 128 tile of unbiased film grain: half the pixels are
               black, half warm white, each with a random alpha, so tiling
               it over a surface neither lightens nor darkens it on average.
scanlines.png  1 x 3 tile: one warm-white line, two transparent rows.

Both are drawn at a few percent opacity by components/atmosphere; the
strength is the user's `appearance.atmosphere.grain` / `.scanlines`.
"""
import random
import struct
import sys
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "atmosphere"
WARM_WHITE = (236, 230, 218)


def png(width: int, height: int, rgba: list[tuple[int, int, int, int]]) -> bytes:
    raw = b"".join(
        b"\x00" + b"".join(struct.pack("4B", *rgba[y * width + x]) for x in range(width))
        for y in range(height)
    )

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(0x484F524E)  # "HORN"
    grain = []
    for _ in range(128 * 128):
        alpha = rng.randint(30, 255)
        grain.append((0, 0, 0, alpha) if rng.random() < 0.5 else (*WARM_WHITE, alpha))
    (OUT / "grain.png").write_bytes(png(128, 128, grain))
    (OUT / "scanlines.png").write_bytes(png(1, 3, [(*WARM_WHITE, 255), (*WARM_WHITE, 0), (*WARM_WHITE, 0)]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
