"""Keyframe map for the Javi painterly reboot pipeline.

Sources of truth:
- assets/companion/sources/poses/*.png — AI-generated key poses on
  green screen, art-directed from the original frames (same
  character, painterly style). Chroma-keyed at derive time.
- assets/companion/sources/orig/*.png — the pre-reboot production
  frames (per-skin idle/walk + default fly), restored verbatim.
  Skins keep their painted identity for idle/walk/greet/talk; the
  new life animations fall back to the default bird, exactly like
  fly did before the reboot (documented fallbackChain).

Each animation is a list of steps; a step names a source keyframe
plus a small procedural transform (dy/rot/sy) applied with PIL to
create in-betweens. Sources: "pose:<name>" (generated keyframe),
"orig:idle"|"orig:walk"|"orig:fly" (per-skin original, falls back
to the generated default pose), "blink-skin" (procedural eyelid
painted over the skin's own idle frame).
"""
from __future__ import annotations

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
    "default": {"label": "Hornero", "palette": {
        "back": "#A85B32", "shadow": "#7A3E22", "crown": "#D98C4E",
        "belly": "#F3DFC2", "throat": "#FFF6E6", "beak": "#7A4A28",
        "outline": "#3E2417"}},
    "argentina": {"label": "Argentina", "palette": {
        "back": "#A85B32", "belly": "#F3DFC2", "garmentA": "#74ACDF",
        "garmentB": "#FFF6E6"}},
    "blue-gold": {"label": "Blue-Gold", "palette": {
        "back": "#A85B32", "belly": "#F3DFC2", "garmentA": "#12306E",
        "garmentB": "#F2B33D"}},
    "red": {"label": "Rojo", "palette": {
        "back": "#A85B32", "belly": "#F3DFC2", "garmentA": "#D03434",
        "garmentB": "#FFF6E6"}},
    "gaucho": {"label": "Gaucho", "palette": {
        "back": "#A85B32", "belly": "#F3DFC2", "garmentA": "#4A2E1E",
        "garmentB": "#93322E"}},
    "nocturnal": {"label": "Nocturnal", "palette": {
        "back": "#4A4364", "shadow": "#2E2A45", "belly": "#D9D4E8"}},
    "retro-terminal": {"label": "Retro Terminal", "palette": {
        "back": "#3E7C4F", "shadow": "#245133", "belly": "#D8F0DC"}},
    "mono": {"label": "Mono", "palette": {
        "back": "#6E6E6E", "shadow": "#454545", "belly": "#EDEDED"}},
}

# Recolors applied to the default bird for palette-only skins
# (source RGB -> target RGB), tolerance-matched in the derive step.
RECOLORS = {
    "nocturnal": [((168, 91, 50), (74, 67, 100)), ((122, 62, 34), (46, 42, 69)),
                  ((217, 140, 78), (124, 116, 168)), ((243, 223, 194), (217, 212, 232))],
    "retro-terminal": [((168, 91, 50), (62, 124, 79)), ((122, 62, 34), (36, 81, 51)),
                       ((217, 140, 78), (145, 200, 162)), ((243, 223, 194), (216, 240, 220))],
    "mono": [((168, 91, 50), (110, 110, 110)), ((122, 62, 34), (69, 69, 69)),
             ((217, 140, 78), (168, 168, 168)), ((243, 223, 194), (237, 237, 237))],
}


def S(src, dy=0, rot=0.0, sy=1.0, crop_head=False):
    return {"src": src, "dy": dy, "rot": rot, "sy": sy, "crop_head": crop_head}


# anim -> (frameMs, loop, next, anchor, steps) for the DEFAULT skin.
SEQUENCES: dict[str, tuple] = {
    "idle": (450, True, "idle", "feet", [
        S("pose:idle"), S("pose:idle", sy=1.015), S("pose:idle", sy=1.02),
        S("pose:idle", sy=1.015)]),
    "blink": (120, False, "idle", "feet", [
        S("pose:idle"), S("pose:blink"), S("pose:idle")]),
    "look": (300, False, "idle", "feet", [
        S("pose:idle", rot=-2), S("pose:idle"), S("pose:idle", rot=2)]),
    "preen": (180, False, "idle", "feet", [
        S("pose:preen"), S("pose:preen", dy=-1, rot=1), S("pose:preen", dy=-2),
        S("pose:preen", dy=-1, rot=-1), S("pose:preen", dy=-2), S("pose:idle")]),
    "stretch": (250, False, "idle", "feet", [
        S("pose:idle"), S("pose:stretch"), S("pose:stretch", sy=1.01),
        S("pose:idle")]),
    "hop": (140, False, "idle", "feet", [
        S("pose:idle", sy=0.94), S("pose:idle", dy=-18), S("pose:idle", dy=-8),
        S("pose:idle", sy=0.97)]),
    "greet": (180, False, "idle", "feet", [
        S("orig:walk"), S("orig:walk", rot=1.5), S("orig:walk", rot=-1.5),
        S("orig:walk")]),
    "walk": (160, True, "idle", "feet", [
        S("pose:walk-step"), S("pose:idle", dy=-2), S("pose:walk-step", dy=-1),
        S("pose:idle", dy=-3), S("pose:walk-step"), S("pose:idle", dy=-2)]),
    "hover": (120, True, "idle", "center", [
        S("pose:fly-down"), S("pose:fly-down", dy=5), S("orig:fly"),
        S("pose:fly-down", dy=3)]),
    "takeoff": (120, False, "fly", "feet", [
        S("pose:idle", sy=0.92), S("pose:fly-down", dy=-12), S("orig:fly")]),
    "fly": (110, True, "idle", "center", [
        S("orig:fly"), S("pose:fly-down", dy=4), S("pose:fly-down", dy=7),
        S("orig:fly", dy=3), S("pose:fly-down", dy=1), S("orig:fly", dy=-2)]),
    "land": (120, False, "idle", "feet", [
        S("pose:fly-down", dy=-10), S("pose:idle", dy=-6),
        S("pose:idle", sy=0.95)]),
    "perch": (500, True, "idle", "feet", [
        S("pose:idle"), S("pose:idle", sy=1.012)]),
    "peek": (400, True, "idle", "feet", [
        S("pose:idle", crop_head=True)]),
    "drag": (300, True, "idle", "center", [
        S("pose:fly-down", rot=-6)]),
    "talk": (140, True, "idle", "feet", [
        S("pose:talk"), S("pose:idle"), S("pose:talk"), S("pose:idle")]),
    "think": (350, True, "idle", "feet", [
        S("pose:think"), S("pose:think", rot=1), S("pose:think"),
        S("pose:think", rot=-1)]),
    "listen": (400, True, "idle", "feet", [
        S("pose:listen"), S("pose:listen", rot=1.5)]),
    "work": (200, True, "idle", "feet", [
        S("pose:work"), S("pose:work", dy=-3), S("pose:work", rot=1),
        S("pose:work", dy=-2)]),
    "approve": (160, False, "idle", "feet", [
        S("pose:celebrate"), S("pose:celebrate", dy=-8),
        S("pose:celebrate", dy=-14), S("pose:idle")]),
    "celebrate": (140, False, "idle", "feet", [
        S("pose:celebrate", dy=-6), S("pose:celebrate", dy=-16),
        S("pose:idle", sy=0.95), S("pose:celebrate", dy=-6),
        S("pose:celebrate", dy=-18), S("pose:idle")]),
    "deny": (180, False, "idle", "feet", [
        S("pose:worry", rot=-3), S("pose:worry", rot=3), S("pose:worry", rot=-2)]),
    "worry": (250, True, "idle", "feet", [
        S("pose:worry", sy=0.97), S("pose:worry", sy=0.99)]),
    "error": (200, False, "idle", "feet", [
        S("pose:worry", rot=4, sy=0.97), S("pose:worry", rot=6, sy=0.95),
        S("pose:worry", rot=4, sy=0.97)]),
    "sleep": (600, True, "idle", "feet", [
        S("pose:sleep"), S("pose:sleep", sy=1.012), S("pose:sleep", sy=1.02),
        S("pose:sleep", sy=1.012)]),
}

# Per-skin identity frames (painted garments from the original set).
# Anything not listed falls back to the default bird (documented).
SKIN_OVERRIDES: dict[str, dict[str, list]] = {
    "argentina": {
        "idle": [S("orig:idle"), S("orig:idle", sy=1.015),
                 S("orig:idle", sy=1.02), S("orig:idle", sy=1.015)],
        "blink": [S("orig:idle"), S("blink-skin"), S("orig:idle")],
        "greet": [S("orig:walk"), S("orig:walk", rot=1.5),
                  S("orig:walk", rot=-1.5), S("orig:walk")],
        "talk": [S("orig:walk"), S("orig:idle"), S("orig:walk"), S("orig:idle")],
        "walk": [S("orig:idle"), S("orig:walk"), S("orig:idle"),
                 S("orig:walk"), S("orig:idle"), S("orig:walk")],
    },
}
for _skin in ("blue-gold", "red", "gaucho"):
    SKIN_OVERRIDES[_skin] = SKIN_OVERRIDES["argentina"]

NEST_STAGES = ("none", "twigs", "cup", "dome", "home")
