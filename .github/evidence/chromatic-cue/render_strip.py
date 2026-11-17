#!/usr/bin/env python3
"""Render a 12-hue Chromatic strip: role swatches + mini surface per seed.

usage: strip.py HELPER OUT.png TITLE
Rows: balanced/vibrant x dark/light. Columns: 12 seed hues (OKLCH L .65
C .15, h = 0, 30, ... 330) plus the host case violet+orange (vapor-dreams).
"""
import json
import math
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

HELPER, OUT, TITLE = sys.argv[1], sys.argv[2], sys.argv[3]
FONT = "IBMPlexSans-Regular.ttf"  # any TTF; falls back to PIL's default
try:
    f_small = ImageFont.truetype(FONT, 11)
    f_text = ImageFont.truetype(FONT, 13)
    f_title = ImageFont.truetype(FONT, 18)
except OSError:
    f_small = f_text = f_title = ImageFont.load_default()


def lch_hex(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l_, m_, s_ = (L + 0.3963377774 * a + 0.2158037573 * b, L - 0.1055613458 * a - 0.0638541728 * b,
                  L - 0.0894841775 * a - 1.2914855480 * b)
    l, m, s = l_**3, m_**3, s_**3
    lin = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s]
    enc = [min(max(12.92 * c if c <= 0.0031308 else 1.055 * max(c, 0) ** (1 / 2.4) - 0.055, 0), 1) for c in lin]
    return "#" + "".join(f"{round(c * 255):02X}" for c in enc)


SEEDS = [([lch_hex(0.65, 0.15, h)], f"{h}°") for h in range(0, 360, 30)]
SEEDS.append((["#8850A1", "#E97241"], "host"))
ROWS = [(v, m) for v in ("balanced", "vibrant") for m in ("dark", "light")]
ROLES = ["signal", "cue", "phosphor", "alert"]
CW, SW, CH = 150, 30, 150
W = 120 + CW * len(SEEDS)
H = 50 + CH * len(ROWS)
img = Image.new("RGB", (W, H), "#202020")
d = ImageDraw.Draw(img)
d.text((12, 12), TITLE, fill="#EEEEEE", font=f_title)

for r, (variant, mode) in enumerate(ROWS):
    y0 = 50 + r * CH
    d.text((10, y0 + 60), f"{variant}\n{mode}", fill="#DDDDDD", font=f_text)
    for c, (seeds, label) in enumerate(SEEDS):
        args = [HELPER, "generate", "--no-cache", "--variant", variant, "--mode", mode]
        for s in seeds:
            args += ["--seed", s]
        doc = json.loads(subprocess.run(args, capture_output=True, text=True, check=True).stdout)
        p = doc["scheme"]["palette"]
        x0 = 120 + c * CW
        # mini surface: ground, panel card, ink text, signal chip, cue focus ring, status dots
        d.rectangle([x0, y0, x0 + CW - 6, y0 + CH - 8], fill=p["ground"])
        d.rectangle([x0 + 6, y0 + 6, x0 + CW - 12, y0 + 92], fill=p["panel"], outline=p["rule"])
        d.text((x0 + 12, y0 + 10), label, fill=p["ink"], font=f_text)
        d.text((x0 + 12, y0 + 28), "muted text", fill=p["inkMuted"], font=f_small)
        d.rounded_rectangle([x0 + 12, y0 + 46, x0 + 66, y0 + 64], 3, fill=p["signal"])
        d.text((x0 + 18, y0 + 48), "Apply", fill=p["onSignal"], font=f_small)
        d.rounded_rectangle([x0 + 72, y0 + 46, x0 + 130, y0 + 64], 3, fill=p["raised"], outline=p["cue"], width=2)
        d.text((x0 + 78, y0 + 48), "focus", fill=p["cue"], font=f_small)
        d.ellipse([x0 + 12, y0 + 72, x0 + 20, y0 + 80], fill=p["phosphor"])
        d.text((x0 + 24, y0 + 69), "ok", fill=p["phosphor"], font=f_small)
        d.ellipse([x0 + 50, y0 + 72, x0 + 58, y0 + 80], fill=p["alert"])
        d.text((x0 + 62, y0 + 69), "err", fill=p["alert"], font=f_small)
        d.text((x0 + 90, y0 + 69), "cue", fill=p["cue"], font=f_small)
        for i, role in enumerate(ROLES):
            d.rectangle([x0 + 6 + i * (SW + 4), y0 + 100, x0 + 6 + i * (SW + 4) + SW, y0 + 124], fill=p[role])
        d.text((x0 + 6, y0 + 126), f"{p['signal']} {p['cue']}", fill=p["inkMuted"], font=f_small)
img.save(OUT)
print(OUT)
