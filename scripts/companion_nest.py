"""Procedural Nest art for the Companion (original, deterministic, Pillow).

A hornero's real nest is a clay oven (horno) with a side entrance. This
draws it as a tiny hacker workshop: clay dome, twigs, a scrap circuit
board, a miniature CRT, a radio transceiver, an antenna and copper wires.
Indicator lights are NOT painted lit: the art carries dark sockets and
the manifest lists their canvas positions (`nestLights`) so the runtime
can light them from real state with Chromatic-aware colours.

Stages: none, twigs, cup, dome, home. Drawn at 2x and downscaled.
"""
from __future__ import annotations

import math

from PIL import Image, ImageDraw

CANVAS = 512
FEET_Y = 472
SS = 2

STAGES = ("none", "twigs", "cup", "dome", "home")

OUT = (58, 34, 22, 255)
SHELF = (92, 58, 32, 255)
SHELF_HI = (122, 80, 46, 255)
CLAY = (150, 98, 58, 255)
CLAY_HI = (178, 124, 76, 255)
CLAY_LO = (112, 70, 40, 255)
TWIG = (96, 62, 34, 255)
TWIG_HI = (130, 88, 50, 255)
COPPER = (206, 126, 62, 255)
COPPER_LO = (150, 86, 40, 255)
PCB = (30, 66, 56, 255)
PCB_HI = (46, 98, 80, 255)
CASE = (84, 70, 62, 255)
CASE_HI = (118, 100, 88, 255)
SCREEN = (12, 22, 24, 255)
PHOSPHOR = (58, 150, 140, 255)
SOCKET = (30, 20, 16, 255)

# Light sockets (canvas px): id -> (x, y, radius, role). Roles are the
# real states the runtime binds them to; the art never lights them.
LIGHTS = {
    "link": (96, 438, 6, "assistant-link"),
    "run": (118, 438, 6, "assistant-run"),
    "approval": (440, 436, 6, "approval"),
    "radio": (462, 436, 6, "radio"),
    "mode": (300, 392, 5, "mode"),
}
# CRT screen rectangle (canvas px) for the runtime phosphor overlay.
SCREEN_RECT = (58, 372, 138, 424)


def _s(v):
    return [int(round(c * SS)) for c in v]


class _Pen:
    def __init__(self):
        self.im = Image.new("RGBA", (CANVAS * SS, CANVAS * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, box, fill, outline=None, r=0, w=2):
        b = _s(box)
        if r:
            self.d.rounded_rectangle(b, radius=r * SS, fill=fill,
                                     outline=outline, width=w * SS)
        else:
            self.d.rectangle(b, fill=fill, outline=outline, width=w * SS)

    def line(self, pts, fill, w=3):
        flat = [int(round(c * SS)) for p in pts for c in p]
        self.d.line(flat, fill=fill, width=int(w * SS), joint="curve")

    def ell(self, box, fill, outline=None, w=2):
        self.d.ellipse(_s(box), fill=fill, outline=outline, width=w * SS)

    def pie(self, box, a0, a1, fill, outline=None, w=3):
        self.d.pieslice(_s(box), a0, a1, fill=fill, outline=outline, width=w * SS)

    def out(self):
        return self.im.resize((CANVAS, CANVAS), Image.LANCZOS)


def _shelf(p):
    p.rect((70, FEET_Y, 442, FEET_Y + 14), SHELF, OUT, r=5)
    p.line([(78, FEET_Y + 4), (432, FEET_Y + 4)], SHELF_HI, 2)


def _twigs(p, n):
    sticks = [((150, 470), (236, 440)), ((176, 472), (262, 452)),
              ((226, 472), (310, 440)), ((192, 462), (286, 466)),
              ((300, 470), (372, 452)), ((120, 472), (190, 458))]
    for a, b in sticks[:n]:
        p.line([a, b], TWIG, 7)
        p.line([(a[0], a[1] - 2), (b[0], b[1] - 2)], TWIG_HI, 2)


def _cup(p):
    p.pie((150, 400, 360, 544), 180, 360, CLAY, OUT, 4)
    p.pie((178, 424, 332, 544), 180, 360, CLAY_LO)
    for i in range(7):
        x = 168 + i * 24
        p.line([(x, 462), (x + 20, 446 - (i % 2) * 4)], TWIG, 4)


def _dome(p):
    # Clay oven, entrance facing the bird (left), slightly lopsided.
    p.pie((236, 292, 462, 652), 180, 360, CLAY, OUT, 5)
    p.ell((282, 318, 370, 352), CLAY_HI)
    for i in range(4):  # trowel rings
        p.d.arc(_s((246 + i * 8, 304 + i * 14, 452 - i * 8, 640 - i * 28)),
                start=200, end=340, fill=CLAY_LO, width=2 * SS)
    p.pie((252, 404, 316, 540), 180, 360, SOCKET, OUT, 4)  # entrance


def _pcb(p, x, y):
    p.rect((x, y, x + 56, y + 30), PCB, OUT, r=3)
    for i in range(4):
        p.line([(x + 8, y + 7 + i * 6), (x + 30 + (i % 2) * 14, y + 7 + i * 6),
                (x + 40, y + 12 + i * 4)], PCB_HI, 2)
    for cx, cy in ((x + 44, y + 8), (x + 12, y + 24)):
        p.ell((cx - 3, cy - 3, cx + 3, cy + 3), COPPER, OUT, 1)


def _crt(p):
    x0, y0, x1, y1 = 44, 356, 152, 450
    p.rect((x0, y0, x1, y1), CASE, OUT, r=12, w=3)
    p.rect((x0 + 4, y0 + 3, x1 - 4, y0 + 8), CASE_HI, None, r=3)
    sx0, sy0, sx1, sy1 = SCREEN_RECT
    p.rect((sx0, sy0, sx1, sy1), SCREEN, OUT, r=8, w=2)
    for i in range(4):  # faint idle phosphor lines
        y = sy0 + 10 + i * 10
        p.line([(sx0 + 10, y), (sx0 + 30 + (i * 13) % 34, y)], PHOSPHOR, 2)
    for lid in ("link", "run"):
        x, y, r, _ = LIGHTS[lid]
        p.ell((x - r - 2, y - r - 2, x + r + 2, y + r + 2), SOCKET, OUT, 1)
        p.ell((x - r + 1, y - r + 1, x + r - 1, y + r - 1), (52, 36, 28, 255))
    p.rect((x0 + 20, y1, x0 + 36, y1 + 22), CASE, OUT, r=2, w=2)  # feet
    p.rect((x1 - 36, y1, x1 - 20, y1 + 22), CASE, OUT, r=2, w=2)


def _radio(p):
    p.rect((410, 416, 472, 468), CASE, OUT, r=6, w=3)
    p.rect((416, 422, 444, 434), SCREEN, OUT, r=2, w=1)
    p.line([(420, 428), (436, 428)], PHOSPHOR, 2)
    p.ell((448, 424, 464, 440), CASE_HI, OUT, 2)
    for i in range(4):
        p.line([(418 + i * 8, 448), (418 + i * 8, 460)], OUT, 2)
    for lid in ("approval", "radio"):
        x, y, r, _ = LIGHTS[lid]
        p.ell((x - r - 2, y - r - 2, x + r + 2, y + r + 2), SOCKET, OUT, 1)
        p.ell((x - r + 1, y - r + 1, x + r - 1, y + r - 1), (52, 36, 28, 255))
    # antenna
    p.line([(462, 416), (478, 340)], COPPER_LO, 3)
    p.line([(478, 340), (470, 322)], COPPER, 2)
    p.line([(462, 330), (494, 346)], COPPER, 2)


def _antenna_dome(p):
    p.line([(380, 318), (388, 262)], COPPER_LO, 3)
    p.line([(370, 276), (404, 270)], COPPER, 2)
    p.line([(374, 290), (400, 286)], COPPER, 2)
    x, y, r, _ = LIGHTS["mode"]
    p.ell((x - r - 2, y - r - 2, x + r + 2, y + r + 2), SOCKET, OUT, 1)
    p.ell((x - r + 1, y - r + 1, x + r - 1, y + r - 1), (52, 36, 28, 255))


def _wires(p):
    # Copper runs from the CRT to the dome and the radio, hung low.
    def sag(a, b, depth):
        pts = []
        for i in range(21):
            t = i / 20
            pts.append((a[0] + (b[0] - a[0]) * t,
                        a[1] + (b[1] - a[1]) * t + math.sin(math.pi * t) * depth))
        return pts
    p.line(sag((150, 440), (252, 452), 14), COPPER_LO, 4)
    p.line(sag((150, 440), (252, 452), 14), COPPER, 2)
    p.line(sag((346, 470), (410, 452), 10), COPPER_LO, 4)
    p.line(sag((346, 470), (410, 452), 10), COPPER, 2)


def nest_image(stage: int) -> Image.Image:
    p = _Pen()
    if stage == 0:
        _shelf(p)
        return p.out()
    _shelf(p)
    if stage == 1:
        _twigs(p, 4)
    elif stage == 2:
        _twigs(p, 6)
        _cup(p)
        _pcb(p, 330, 440)
    elif stage == 3:
        _twigs(p, 3)
        _dome(p)
        _pcb(p, 120, 440)
    else:
        _twigs(p, 2)
        _dome(p)
        _antenna_dome(p)
        _crt(p)
        _radio(p)
        _wires(p)
    return p.out()


def lights_manifest() -> dict:
    return {k: {"x": v[0], "y": v[1], "r": v[2], "role": v[3]}
            for k, v in LIGHTS.items()}
