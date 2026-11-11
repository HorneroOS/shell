"""Parameterized SVG masters for Javi el Hornero (visual reboot).

One flat-vector hornero, drawn facing RIGHT on a 512x512 canvas with
feet baseline y=472. Poses are parameter sets over named groups
(body tilt, head tilt, wing mode/angle, eye/beak variants, leg modes,
props); skins are palette + garment/accessory substitutions applied
at render time by scripts/derive-companion-assets.py.

Tokens like @BACK@ in the emitted SVG are replaced per skin before
rsvg-convert renders the production PNG frames. Character bible:
docs/COMPANION.md (silhouette, proportions, expression set).
"""
from __future__ import annotations

CANVAS = 512
FEET_Y = 472

# anim id -> (frameMs, loop, next, anchor, [pose param dicts])
# Pose params (all optional, defaults = idle stance):
#   tilt: whole-body rotate deg around feet anchor
#   dy: whole-body vertical offset px (hop/crouch; negative = up)
#   scale_y: breathe squash around feet anchor (1.0 = none)
#   head: (dx, dy, rotateDeg around neck pivot)
#   eye: open|half|closed|happy|worried
#   beak: closed|parted|open|loaded
#   wing: (mode, angleDeg) mode in folded|raised|half|spread|tucked|point
#   legs: stand|walkA|walkB|tucked|dangle|stretch
#   tail: rotate deg around tail base
#   prop: ''|twig|mud|seed
#   air: bool (airborne: recentre on canvas center, legs tucked)


def _p(**kw):
    return kw


ANIMATIONS: dict[str, tuple] = {
    "idle": (450, True, "idle", "feet", [
        _p(scale_y=1.0), _p(scale_y=1.015), _p(scale_y=1.02), _p(scale_y=1.015)]),
    "blink": (120, False, "idle", "feet", [
        _p(), _p(eye="half"), _p(eye="closed")]),
    "look": (300, False, "idle", "feet", [
        _p(head=(0, 0, -14)), _p(), _p(head=(4, 2, 10))]),
    "preen": (180, False, "idle", "feet", [
        _p(head=(-18, 16, 22)), _p(head=(-42, 44, 38), wing=("half", -18)),
        _p(head=(-52, 58, 46), wing=("half", -24)),
        _p(head=(-42, 44, 38), wing=("half", -18)),
        _p(head=(-52, 58, 46), wing=("half", -24)), _p(head=(-10, 8, 10))]),
    "stretch": (250, False, "idle", "feet", [
        _p(), _p(wing=("half", -34), legs="stretch", head=(2, -4, -6)),
        _p(wing=("half", -42), legs="stretch", head=(2, -6, -8)),
        _p(wing=("half", -20), head=(0, -2, -3))]),
    "hop": (140, False, "idle", "feet", [
        _p(scale_y=0.94), _p(dy=-16, legs="tucked", wing=("half", -26)),
        _p(dy=-6, legs="dangle"), _p(scale_y=0.97)]),
    "greet": (180, False, "idle", "feet", [
        _p(wing=("raised", -30), eye="happy"),
        _p(wing=("raised", -52), eye="happy", beak="parted"),
        _p(wing=("raised", -66), eye="happy", beak="open"),
        _p(wing=("raised", -40), eye="happy")]),
    "walk": (160, True, "idle", "feet", [
        _p(legs="walkA", dy=0), _p(legs="stand", dy=-3),
        _p(legs="walkB", dy=0), _p(legs="stand", dy=-3),
        _p(legs="walkA", dy=-1), _p(legs="stand", dy=-2)]),
    "hover": (120, True, "idle", "center", [
        _p(air=True, wing=("spread", -38)),
        _p(air=True, wing=("spread", 18), dy=4),
        _p(air=True, wing=("spread", -8), dy=2),
        _p(air=True, wing=("spread", 26), dy=5)]),
    "takeoff": (120, False, "fly", "feet", [
        _p(scale_y=0.92, wing=("half", -30)),
        _p(dy=-10, legs="tucked", wing=("spread", -44)),
        _p(air=True, wing=("spread", -20))]),
    "fly": (110, True, "idle", "center", [
        _p(air=True, wing=("spread", -52)),
        _p(air=True, wing=("spread", -18), dy=3),
        _p(air=True, wing=("spread", 22), dy=6),
        _p(air=True, wing=("spread", 40), dy=4),
        _p(air=True, wing=("spread", 8), dy=1),
        _p(air=True, wing=("spread", -30), dy=-2)]),
    "land": (120, False, "idle", "feet", [
        _p(air=True, wing=("spread", -30), legs="dangle"),
        _p(dy=-8, legs="dangle", wing=("half", -36)),
        _p(scale_y=0.95, wing=("folded", 0))]),
    "perch": (500, True, "idle", "feet", [
        _p(legs="grip"), _p(legs="grip", scale_y=1.012)]),
    "peek": (400, True, "idle", "feet", [
        _p(peek=True)]),
    "drag": (300, True, "idle", "center", [
        _p(air=True, wing=("half", -14), legs="dangle", eye="half")]),
    "talk": (140, True, "idle", "feet", [
        _p(beak="closed"), _p(beak="parted"), _p(beak="open"), _p(beak="parted")]),
    "think": (350, True, "idle", "feet", [
        _p(eye="half", head=(0, 2, 12), wing=("point", 0)),
        _p(eye="half", head=(0, 4, 16), wing=("point", 0)),
        _p(eye="half", head=(0, 2, 12), wing=("point", 0)),
        _p(eye="half", head=(0, 0, 8), wing=("point", 0))]),
    "listen": (400, True, "idle", "feet", [
        _p(head=(-2, -2, -12)), _p(head=(-2, 0, -16))]),
    "work": (200, True, "idle", "feet", [
        _p(beak="loaded", prop="twig", legs="walkA"),
        _p(beak="loaded", prop="twig", legs="stand", dy=-3),
        _p(beak="loaded", prop="twig", legs="walkB"),
        _p(beak="loaded", prop="mud", legs="stand", dy=-3)]),
    "approve": (160, False, "idle", "feet", [
        _p(wing=("raised", -36), eye="happy"),
        _p(wing=("raised", -58), eye="happy", dy=-6),
        _p(wing=("raised", -64), eye="happy", beak="open", dy=-12, legs="tucked"),
        _p(wing=("raised", -30), eye="happy")]),
    "celebrate": (140, False, "idle", "feet", [
        _p(wing=("raised", -44), eye="happy", dy=-6),
        _p(wing=("raised", -64), eye="happy", beak="open", dy=-16, legs="tucked"),
        _p(eye="happy", scale_y=0.95),
        _p(wing=("raised", -44), eye="happy", dy=-6),
        _p(wing=("raised", -64), eye="happy", beak="open", dy=-18, legs="tucked"),
        _p(eye="happy")]),
    "deny": (180, False, "idle", "feet", [
        _p(eye="worried", head=(-6, 2, -10), wing=("half", -20)),
        _p(eye="worried", head=(6, 2, 8), wing=("half", -24)),
        _p(eye="worried", head=(-4, 2, -6), wing=("half", -20))]),
    "worry": (250, True, "idle", "feet", [
        _p(eye="worried", scale_y=0.97),
        _p(eye="worried", scale_y=0.99, dy=0)]),
    "error": (200, False, "idle", "feet", [
        _p(eye="half", head=(0, 10, 14), tail=-16),
        _p(eye="half", head=(0, 16, 20), tail=-22, scale_y=0.96),
        _p(eye="half", head=(0, 10, 12), tail=-14)]),
    "sleep": (600, True, "idle", "feet", [
        _p(eye="closed", head=(-14, 22, 26), wing=("tucked", 0)),
        _p(eye="closed", head=(-14, 24, 26), wing=("tucked", 0), scale_y=1.012),
        _p(eye="closed", head=(-14, 22, 26), wing=("tucked", 0), scale_y=1.02),
        _p(eye="closed", head=(-14, 24, 26), wing=("tucked", 0), scale_y=1.012)]),
}

ASSISTANT_STATES = {
    "resting": "idle",
    "listening": "listen",
    "thinking": "think",
    "acting": "work",
    "speaking": "talk",
    "success": "approve",
    "warning": "worry",
    "denied": "deny",
    "error": "error",
}

SKINS = {
    "default": {
        "label": "Hornero", "garment": None, "accessories": [],
        "palette": {"back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
                    "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
                    "outline": "#3E2417"},
    },
    "argentina": {
        "label": "Argentina", "garment": "argentina", "accessories": [],
        "palette": {"back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
                    "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
                    "outline": "#3E2417", "garmentA": "#74ACDF", "garmentB": "#FFF6E6"},
    },
    "blue-gold": {
        "label": "Blue-Gold", "garment": "blue-gold", "accessories": [],
        "palette": {"back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
                    "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
                    "outline": "#3E2417", "garmentA": "#12306E", "garmentB": "#F2B33D"},
    },
    "red": {
        "label": "Rojo", "garment": "red", "accessories": [],
        "palette": {"back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
                    "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
                    "outline": "#3E2417", "garmentA": "#D03434", "garmentB": "#FFF6E6"},
    },
    "gaucho": {
        "label": "Gaucho", "garment": None, "accessories": ["boina", "kerchief"],
        "palette": {"back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
                    "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
                    "outline": "#3E2417", "garmentA": "#4A2E1E", "garmentB": "#93322E"},
    },
    "nocturnal": {
        "label": "Nocturnal", "garment": None, "accessories": [],
        "palette": {"back": "#4A4364", "shadow": "#2E2A45", "crown": "#7C74A8",
                    "belly": "#D9D4E8", "throat": "#F2EFFA", "beak": "#3A3450",
                    "outline": "#1D1A2C"},
    },
    "retro-terminal": {
        "label": "Retro Terminal", "garment": None, "accessories": [],
        "palette": {"back": "#3E7C4F", "shadow": "#245133", "crown": "#91C8A2",
                    "belly": "#D8F0DC", "throat": "#F0FFF2", "beak": "#2C4A34",
                    "outline": "#12251A"},
    },
    "mono": {
        "label": "Mono", "garment": None, "accessories": [],
        "palette": {"back": "#6E6E6E", "shadow": "#454545", "crown": "#A8A8A8",
                    "belly": "#EDEDED", "throat": "#FFFFFF", "beak": "#555555",
                    "outline": "#222222"},
    },
}

NEST_STAGES = ("none", "twigs", "cup", "dome", "home")

_STROKE = 'stroke="@OUTLINE@" stroke-width="6" stroke-linejoin="round" stroke-linecap="round"'


def _eye(variant: str, x: float, y: float) -> str:
    if variant == "closed":
        return f'<path d="M{x-13},{y+2} Q{x},{y+10} {x+13},{y+2}" fill="none" stroke="@EYEC@" stroke-width="6" stroke-linecap="round"/>'
    if variant == "happy":
        return f'<path d="M{x-13},{y+6} Q{x},{y-10} {x+13},{y+6}" fill="none" stroke="@EYEC@" stroke-width="6" stroke-linecap="round"/>'
    base = (f'<circle cx="{x}" cy="{y}" r="15" fill="@EYEC@"/>'
            f'<circle cx="{x+5}" cy="{y-5}" r="4.5" fill="#FFFFFF"/>')
    if variant == "half":
        base += f'<path d="M{x-15},{y-12} L{x+15},{y-12} L{x+15},{y-1} Q{x},{y+5} {x-15},{y-1} Z" fill="@BACK@"/>'
    if variant == "worried":
        base += f'<path d="M{x-15},{y-24} L{x+13},{y-17}" stroke="@OUTLINE@" stroke-width="6" stroke-linecap="round"/>'
    return base


def _beak(variant: str, prop: str) -> str:
    out = ""
    if variant in ("parted", "open"):
        gap = 7 if variant == "parted" else 13
        out = (f'<path d="M432,196 L496,208 L434,214 Z" fill="@BEAK@" {_STROKE}/>'
               f'<path d="M434,{214+gap} L488,{216+gap} L432,228 Z" fill="@BEAK@" {_STROKE}/>')
    else:
        out = f'<path d="M432,196 L496,212 L432,230 Z" fill="@BEAK@" {_STROKE}/>'
    if prop == "twig":
        out += ('<path d="M470,206 L508,182 M482,200 L500,178 M486,214 L510,206" '
                'stroke="#5C3A20" stroke-width="7" stroke-linecap="round"/>')
    elif prop == "mud":
        out += '<circle cx="492" cy="214" r="13" fill="#8A5A34" stroke="@OUTLINE@" stroke-width="5"/>'
    elif prop == "seed":
        out += '<ellipse cx="492" cy="214" rx="12" ry="8" fill="#E8B84B" stroke="@OUTLINE@" stroke-width="5"/>'
    return out


def _wing(mode: str, angle: float) -> str:
    # Wing teardrop hung from the shoulder pivot (292, 248).
    if mode == "spread":
        path = "M292,248 C240,170 150,120 84,132 C140,196 210,262 292,270 Z"
    elif mode == "point":
        path = "M292,248 C330,290 368,330 392,378 C340,368 296,322 284,272 Z"
    elif mode == "tucked":
        path = "M292,248 C240,270 196,330 196,392 C250,392 300,340 306,268 Z"
    else:  # folded / raised / half share the folded teardrop, rotated
        path = "M292,248 C228,262 184,318 190,386 C246,380 300,330 308,264 Z"
    return (f'<g transform="rotate({angle} 292 248)">'
            f'<path d="{path}" fill="@SHADOW@" {_STROKE}/>'
            f'<path d="M286,272 C248,292 224,324 220,356" fill="none" '
            f'stroke="@CROWN@" stroke-width="8" stroke-linecap="round" opacity="0.7"/></g>')


def _legs(mode: str) -> str:
    def leg(x1, y1, x2, y2):
        toes = "".join(
            f'<path d="M{x2},{y2} l{dx},0" stroke="@BEAK@" stroke-width="5" stroke-linecap="round"/>'
            for dx in (-11, 0, 11))
        return (f'<path d="M{x1},{y1} L{x2},{y2}" stroke="@BEAK@" '
                f'stroke-width="7" stroke-linecap="round"/>{toes}')
    if mode == "tucked":
        return leg(238, 414, 232, 438) + leg(292, 416, 288, 440)
    if mode == "dangle":
        return leg(238, 414, 230, 462) + leg(292, 416, 298, 464)
    if mode == "walkA":
        return leg(238, 414, 216, FEET_Y) + leg(292, 416, 312, FEET_Y - 14)
    if mode == "walkB":
        return leg(238, 414, 252, FEET_Y - 14) + leg(292, 416, 276, FEET_Y)
    if mode == "stretch":
        return leg(238, 414, 236, FEET_Y) + leg(292, 416, 200, 428)
    if mode == "grip":
        # Branch segment under the feet, ending exactly at the baseline.
        return (f'<rect x="196" y="{FEET_Y - 7}" width="138" height="7" rx="3" '
                f'fill="#5C3A20"/>'
                + leg(238, 414, 236, FEET_Y - 6) + leg(292, 416, 290, FEET_Y - 6))
    return leg(238, 414, 236, FEET_Y) + leg(292, 416, 290, FEET_Y)


def _garment(kind: str | None) -> str:
    if not kind:
        return ""
    clip = ('<clipPath id="garmentClip"><path d="M196,300 '
            'C210,380 280,428 348,414 C404,402 428,356 424,306 '
            'C380,330 300,336 240,322 C222,318 206,310 196,300 Z"/></clipPath>')
    shape = ('<path d="M196,300 C210,380 280,428 348,414 C404,402 '
             f'428,356 424,306 C380,330 300,336 240,322 C222,318 206,310 196,300 Z" fill="@GARMENTA@" {_STROKE}/>')
    if kind == "argentina":
        detail = "".join(
            f'<rect x="{x}" y="290" width="26" height="150" fill="@GARMENTB@"/>'
            for x in (232, 284, 336, 388))
    elif kind == "blue-gold":
        detail = '<rect x="190" y="338" width="250" height="34" fill="@GARMENTB@"/>'
    else:  # red: white V trim
        detail = ('<path d="M300,322 L340,356 L380,320" fill="none" '
                  'stroke="@GARMENTB@" stroke-width="10" stroke-linecap="round"/>')
    return clip + f'<g clip-path="url(#garmentClip)">{shape}{detail}</g>' + shape.replace(
        'fill="@GARMENTA@"', 'fill="none"')


def _accessories(items: list) -> str:
    out = ""
    if "boina" in items:
        out += ('<g transform="rotate(-14 348 128)">'
                '<ellipse cx="348" cy="128" rx="62" ry="20" fill="@GARMENTA@" '
                f'{_STROKE}/><circle cx="392" cy="116" r="7" fill="@GARMENTA@"/></g>')
    if "kerchief" in items:
        out += ('<path d="M330,262 L396,258 L362,318 Z" fill="@GARMENTB@" '
                f'{_STROKE}/><circle cx="364" cy="262" r="8" fill="@GARMENTB@"/>')
    return out


def pose_svg(pose: dict, garment: str | None = "@GARMENT@",
             accessories=("@ACCESSORIES@",)) -> str:
    """Skin-neutral SVG for one pose frame.

    Garment/accessory placeholders stay literal here; the derive
    script substitutes the per-skin garment block, accessories and
    palette tokens. When garment is a concrete kind the block is
    inlined (used for previews).
    """
    eye = pose.get("eye", "open")
    beak = pose.get("beak", "closed")
    wing_mode, wing_angle = pose.get("wing", ("folded", 0))
    legs = pose.get("legs", "stand")
    head_dx, head_dy, head_rot = pose.get("head", (0, 0, 0))
    tail_rot = pose.get("tail", 0)
    prop = pose.get("prop", "")
    air = bool(pose.get("air", False))
    if air and legs == "stand":
        legs = "tucked"
    dy = pose.get("dy", 0)
    scale_y = pose.get("scale_y", 1.0)
    tilt = pose.get("tilt", -16 if air else 0)

    garment_block = _garment(garment) if garment != "@GARMENT@" else "@GARMENT@"
    accessory_block = ("@ACCESSORIES@" if list(accessories) == ["@ACCESSORIES@"]
                       else _accessories(list(accessories)))

    head = (
        f'<g transform="translate({head_dx} {head_dy}) rotate({head_rot} 340 250)">'
        f'<circle cx="362" cy="196" r="78" fill="@BACK@" {_STROKE}/>'
        f'<path d="M300,152 C330,120 384,118 414,148 C384,132 330,132 300,152 Z" fill="@CROWN@"/>'
        f'<ellipse cx="392" cy="228" rx="34" ry="26" fill="@THROAT@"/>'
        f'{accessory_block}{_eye(eye, 382, 192)}{_beak(beak, prop)}</g>')
    bird = (
        f'<g transform="rotate({tail_rot} 176 330)">'
        f'<path d="M184,318 L86,236 L112,338 L150,366 Z" fill="@SHADOW@" {_STROKE}/></g>'
        f'{_legs(legs)}'
        f'<path d="M150,306 C156,214 226,158 310,166 C392,174 436,238 430,314 '
        f'C424,392 346,434 262,428 C196,423 150,386 150,306 Z" fill="@BACK@" {_STROKE}/>'
        f'<path d="M196,316 C216,382 282,420 344,408 C396,398 420,360 418,318 '
        f'C370,344 276,346 196,316 Z" fill="@BELLY@"/>'
        f'{garment_block}{_wing(wing_mode, wing_angle)}{head}')
    if pose.get("peek"):
        # Head + shoulder only, larger, anchored low-left of canvas.
        inner = (f'<g transform="translate(-120 130) scale(1.25)">{bird}</g>')
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
                f'width="512" height="512">{inner}</svg>')
    if air:
        group = (f'<g transform="translate(-16 {-21 + dy}) rotate({tilt} 291 295) '
                 f'scale(1 {scale_y})">{bird}</g>')
    else:
        # -4: toe stroke extends past the baseline; keep pixels ending at FEET_Y.
        group = (f'<g transform="translate(256 {FEET_Y - 4 + dy}) rotate({tilt}) '
                 f'scale(0.9 {0.9 * scale_y}) translate(-256 -{FEET_Y})">{bird}</g>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
            f'width="512" height="512">{group}</svg>')


def nest_svg(stage: int) -> str:
    """512x512 nest prop, drawn at the feet baseline under Javi."""
    sill = f'<rect x="120" y="{FEET_Y}" width="272" height="10" fill="#5C3A20"/>'
    twigs = ('<path d="M196,470 L286,446 M216,472 L300,456 M246,472 L316,448 '
             'M206,466 L268,470" stroke="#5C3A20" stroke-width="8" stroke-linecap="round"/>')
    cup = (f'<path d="M188,{FEET_Y} C196,424 232,404 256,404 C280,404 316,424 324,{FEET_Y} '
           f'L306,{FEET_Y} C300,434 278,422 256,422 C234,422 212,434 206,{FEET_Y} Z" '
           f'fill="#8A5A34" {_STROKE.replace("@OUTLINE@", "#3E2417")}/>')
    dome = (f'<path d="M176,{FEET_Y} C176,396 214,358 256,358 C298,358 336,396 336,{FEET_Y} Z" '
            f'fill="#8A5A34" {_STROKE.replace("@OUTLINE@", "#3E2417")}/>'
            f'<circle cx="292" cy="430" r="17" fill="#3E2417"/>')
    home_extra = ('<path d="M292,430 L336,438 L336,458 L292,448 Z" fill="#6E4525" '
                  'stroke="#3E2417" stroke-width="5"/>'
                  '<ellipse cx="222" cy="392" rx="12" ry="6" fill="#D98C4E" '
                  'transform="rotate(-24 222 392)"/>')
    body = {0: sill, 1: sill + twigs, 2: sill + cup,
            3: sill + dome, 4: sill + dome + home_extra}[stage]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" '
            f'width="512" height="512">{body}</svg>')

