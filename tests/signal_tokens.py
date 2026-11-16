"""Parse the Hornero Signal built-in role tables from services/Signal.qml."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIGNAL = ROOT / "services" / "Signal.qml"

SURFACES = ("ground", "sunken", "base", "panel", "raised", "lifted")
ROLES = ("ground", "sunken", "base", "panel", "raised", "lifted", "ink", "inkMuted",
         "inkFaint", "rule", "ruleStrong", "focus", "signal", "onSignal", "signalWell",
         "onSignalWell", "cue", "onCue", "cueWell", "onCueWell", "phosphor", "onPhosphor",
         "phosphorWell", "onPhosphorWell", "alert", "onAlert", "alertWell", "onAlertWell",
         "inverse", "onInverse", "inverseSignal", "scrim", "shadow")
# Optional roles (amendment 2): a theme may omit them; they fall back.
OPTIONAL_ROLES = {"glow": "signal"}
BUILT_INS = ("hornero-signal-night", "hornero-signal-day", "hornero-signal-contrast")


def built_in_themes() -> dict:
    text = SIGNAL.read_text(encoding="utf-8")
    block = text.split("readonly property var builtInThemes: (", 1)[1]
    block = block.split("\n        })", 1)[0] + "\n        }"
    return json.loads(block)


def luminance(value: str) -> float:
    channels = [int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(fg: str, bg: str) -> float:
    hi, lo = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def palette_defaults() -> dict:
    """Defaults of the SignalPalette component (first frame)."""
    text = SIGNAL.read_text(encoding="utf-8")
    out = {}
    for header in ("component SignalInkRoles: QtObject {", "component SignalPalette: SignalInkRoles {"):
        block = text.split(header, 1)[1].split("\n    }", 1)[0]
        out.update(re.findall(r'property color (\w+): "(#[0-9A-Fa-f]{6})"', block))
    return out
