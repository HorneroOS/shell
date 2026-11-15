"""WCAG 2.2 AA contrast regression gate for builtin palettes.

Ratios use relative luminance (sRGB) over opaque declared backgrounds.
Text pairs must reach 4.5:1 (SC 1.4.3, normal text; the shell default
is 12pt, not large text), essential component borders 3:1 (SC 1.4.11).
Dynamic wallpaper-generated palettes are out of scope: no hex in repo.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COLOURS = (ROOT / "services/Colours.qml").read_text()


def _palette(name: str) -> dict:
    if name == "highContrast":
        block = COLOURS.split("highContrastPalette: M3Palette {", 1)[1].split("\n    }", 1)[0]
        return dict(re.findall(r'(m3\w+):\s*"(#[0-9a-fA-F]{6})"', block))
    table = COLOURS.split(f'readonly property var _{name}: ({{', 1)[1].split("\n    })", 1)[0]
    return {"m3" + k: v for k, v in re.findall(r'"(\w+)":\s*"(#[0-9a-fA-F]{6})"', table)}


def _lum(hexcolor: str) -> float:
    rgb = [int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    rgb = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def _ratio(fg: str, bg: str) -> float:
    hi, lo = sorted((_lum(fg), _lum(bg)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


PALETTES = {name: _palette(name) for name in ("horneroDark", "horneroLight", "highContrast")}

TEXT_PAIRS = [
    ("m3onSurface", "m3surface"),
    ("m3onSurface", "m3surfaceContainer"),
    ("m3onSurfaceVariant", "m3surface"),
    ("m3onSurfaceVariant", "m3surfaceContainer"),
    ("m3onSurfaceVariant", "m3surfaceContainerHighest"),
    ("m3onPrimary", "m3primary"),
    ("m3onPrimaryContainer", "m3primaryContainer"),
    ("m3onErrorContainer", "m3errorContainer"),
]

BORDER_PAIRS = [
    ("m3outline", "m3surface"),
    ("m3outline", "m3surfaceContainer"),
    ("m3outline", "m3surfaceContainerHighest"),
    ("m3primary", "m3surface"),  # focusRing = m3primary
]


def test_text_pairs_meet_aa():
    for name, pal in PALETTES.items():
        for fg, bg in TEXT_PAIRS:
            assert _ratio(pal[fg], pal[bg]) >= 4.5, (name, fg, bg, _ratio(pal[fg], pal[bg]))


def test_component_border_pairs_meet_nontext_aa():
    for name, pal in PALETTES.items():
        for fg, bg in BORDER_PAIRS:
            assert _ratio(pal[fg], pal[bg]) >= 3.0, (name, fg, bg, _ratio(pal[fg], pal[bg]))


def test_outline_is_never_text_colour():
    for rel in ("components/SectionHeader.qml", "components/PropertyRow.qml",
                "modules/controlcenter/components/SliderInput.qml"):
        src = (ROOT / rel).read_text()
        assert "color: Colours.palette.m3outline\n" not in src, rel


def test_pluginkit_essential_borders_use_component_border():
    kit = ROOT / "plugin/qml/Hornero/PluginKit"
    assert "componentBorder: Colours.palette.m3outline" in (kit / "Theme.qml").read_text()
    for name in ("UiTooltip.qml", "UiPopover.qml"):
        src = (kit / name).read_text()
        assert "border.color: Theme.componentBorder" in src, name
        assert "border.color: Theme.outlineVariant" not in src, name
    for name in ("UiSlider.qml", "UiProgress.qml", "UiChip.qml"):
        assert "border.color: Theme.componentBorder" in (kit / name).read_text(), name
