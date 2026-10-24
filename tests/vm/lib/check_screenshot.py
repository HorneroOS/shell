#!/usr/bin/env python3
"""Reject blank or truncated screenshots without third-party dependencies.

Usage: check_screenshot.py [--min-colors N] [--min-stddev F] [--min-bytes N]
                            [--region X,Y,WIDTH,HEIGHT] [--different-from FILE]
                            [--min-diff-ratio F] [--quiet] FILE...

A capture counts as non-blank when it holds at least --min-colors distinct
sampled colors and the population standard deviation of sampled luminance
reaches --min-stddev. `--region` limits those measurements to a rectangle.
Only 8-bit non-interlaced PNG files (what grim and ppm_to_png.py produce) are
accepted.

Exit status: 0 when every file passes, 1 when any file fails, 2 on usage
or unreadable-file errors.
"""

import argparse
import math
import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS = {0: 1, 2: 3, 4: 2, 6: 4}
MAX_SAMPLES = 200000


def parse_png(path):
    with open(path, "rb") as handle:
        data = handle.read()
    if data[:8] != PNG_SIGNATURE:
        raise ValueError("not a PNG file")
    pos, width, height, idat = 8, None, None, b""
    while pos + 8 <= len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        if len(payload) != length:
            raise ValueError("truncated PNG chunk")
        if tag == b"IHDR":
            width, height, depth, color, _comp, _filt, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if depth != 8:
                raise ValueError(f"only 8-bit PNG is supported (depth {depth})")
            if color not in CHANNELS:
                raise ValueError(f"unsupported PNG color type {color}")
            if interlace != 0:
                raise ValueError("interlaced PNG is not supported")
            channels = CHANNELS[color]
        elif tag == b"IDAT":
            idat += payload
        elif tag == b"IEND":
            break
        pos += 12 + length
    if width is None:
        raise ValueError("missing IHDR")
    raw = zlib.decompress(idat)
    stride = width * channels
    pixels, prev, offset = bytearray(), bytearray(stride), 0
    for _ in range(height):
        filt = raw[offset]
        offset += 1
        line = bytearray(raw[offset:offset + stride])
        offset += stride
        if filt == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filt == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:  # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif filt == 4:  # Paeth
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = prev[i]
                up_left = prev[i - channels] if i >= channels else 0
                pred = paeth(left, up, up_left)
                line[i] = (line[i] + pred) & 0xFF
        elif filt != 0:
            raise ValueError(f"unknown PNG filter {filt}")
        pixels += line
        prev = line
    return width, height, channels, bytes(pixels)


def paeth(left, up, up_left):
    base = left + up - up_left
    dist = (abs(base - left), abs(base - up), abs(base - up_left))
    return (left, up, up_left)[dist.index(min(dist))]


def luminance(pixel, channels):
    if channels == 1:
        return float(pixel[0])
    if channels == 2:
        return float(pixel[0])
    return 0.2126 * pixel[0] + 0.7152 * pixel[1] + 0.0722 * pixel[2]


def assess(path, min_colors, min_stddev, min_bytes, region=None):
    import os

    # Parse first: an unparseable artifact is a harness error (the caller
    # reports exit 2), while a parseable but empty frame is a product
    # failure (exit 1).
    width, height, channels, pixels = parse_png(path)
    size = os.path.getsize(path)
    if size < min_bytes:
        return False, f"only {size} bytes (minimum {min_bytes})"
    if region is None:
        x0, y0, region_width, region_height = 0, 0, width, height
    else:
        x0, y0, region_width, region_height = region
        if (
            x0 < 0
            or y0 < 0
            or region_width <= 0
            or region_height <= 0
            or x0 + region_width > width
            or y0 + region_height > height
        ):
            raise ValueError(
                f"region {region} is outside image bounds {width}x{height}"
            )

    total = region_width * region_height
    step = max(1, math.ceil(math.sqrt(total / MAX_SAMPLES)))
    colors, total_luma, total_sq, count = set(), 0.0, 0.0, 0
    for y in range(y0, y0 + region_height, step):
        for x in range(x0, x0 + region_width, step):
            base = (y * width + x) * channels
            pixel = pixels[base:base + channels]
            if len(colors) < 4096:
                colors.add(bytes(pixel))
            luma = luminance(pixel, channels)
            total_luma += luma
            total_sq += luma * luma
            count += 1
    mean = total_luma / count
    stddev = math.sqrt(max(0.0, total_sq / count - mean * mean))
    if len(colors) < min_colors:
        return False, f"only {len(colors)} distinct colors (minimum {min_colors})"
    if stddev < min_stddev:
        return False, f"luminance stddev {stddev:.2f} (minimum {min_stddev})"
    return True, f"{width}x{height}, colors={len(colors)}, stddev={stddev:.2f}"


def compare_to_reference(path, reference, region=None, min_diff_ratio=0.05):
    width, height, channels, pixels = parse_png(path)
    ref_width, ref_height, ref_channels, ref_pixels = parse_png(reference)
    if (width, height, channels) != (ref_width, ref_height, ref_channels):
        raise ValueError(
            "screenshot and reference dimensions or color formats differ "
            f"({width}x{height}/{channels}, {ref_width}x{ref_height}/{ref_channels})"
        )
    if region is None:
        x0, y0, region_width, region_height = 0, 0, width, height
    else:
        x0, y0, region_width, region_height = region
        if (
            x0 < 0
            or y0 < 0
            or region_width <= 0
            or region_height <= 0
            or x0 + region_width > width
            or y0 + region_height > height
        ):
            raise ValueError(
                f"region {region} is outside image bounds {width}x{height}"
            )

    total = region_width * region_height
    step = max(1, math.ceil(math.sqrt(total / MAX_SAMPLES)))
    changed = count = 0
    for y in range(y0, y0 + region_height, step):
        for x in range(x0, x0 + region_width, step):
            offset = (y * width + x) * channels
            if pixels[offset:offset + channels] != ref_pixels[offset:offset + channels]:
                changed += 1
            count += 1
    ratio = changed / count
    return ratio >= min_diff_ratio, f"{ratio:.1%} of sampled pixels differ from reference"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min-colors", type=int, default=16)
    parser.add_argument("--min-stddev", type=float, default=3.0)
    parser.add_argument("--min-bytes", type=int, default=1024)
    parser.add_argument(
        "--region",
        help="measure only x,y,width,height inside each image",
    )
    parser.add_argument(
        "--different-from",
        help="require each screenshot to differ from this reference image",
    )
    parser.add_argument(
        "--min-diff-ratio",
        type=float,
        default=0.05,
        help="minimum changed sample ratio when --different-from is used (default: 0.05)",
    )
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("files", nargs="+")
    args = parser.parse_args(argv)

    if not 0.0 <= args.min_diff_ratio <= 1.0:
        parser.error("--min-diff-ratio must be between 0 and 1")

    region = None
    if args.region:
        try:
            values = tuple(int(value) for value in args.region.split(","))
        except ValueError:
            parser.error("--region must contain four comma-separated integers")
        if len(values) != 4:
            parser.error("--region must contain four comma-separated integers")
        region = values

    failed, errors = False, False
    for path in args.files:
        try:
            ok, detail = assess(
                path, args.min_colors, args.min_stddev, args.min_bytes, region
            )
            if args.different_from:
                differs, difference = compare_to_reference(
                    path, args.different_from, region, args.min_diff_ratio
                )
                if not differs:
                    ok = False
                detail += f", {difference}"
        except (OSError, ValueError, struct.error, zlib.error) as exc:
            errors = True
            if not args.quiet:
                print(f"ERROR {path} ({exc})")
            continue
        if ok:
            if not args.quiet:
                print(f"PASS {path} ({detail})")
        else:
            failed = True
            if not args.quiet:
                print(f"FAIL {path} ({detail})")
    if errors:
        return 2
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
