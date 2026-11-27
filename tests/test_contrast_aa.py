"""WCAG 2.2 AA contrast gate for the Hornero Signal built-in themes.

Ratios use relative luminance (sRGB) over opaque declared backgrounds.
Text pairs must reach 4.5:1 (SC 1.4.3; the shell default is 12pt, not
large text), essential component boundaries 3:1 (SC 1.4.11). Tables come
from services/Signal.qml (RFC 0001 §3.2 values).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from signal_tokens import (BUILT_INS, OPTIONAL_ROLES, ROLES, ROOT, SURFACES,  # noqa: E402
                           built_in_themes, contrast, palette_defaults)

THEMES = built_in_themes()
ACCENTS = ("signal", "cue", "phosphor", "alert")


def _on(role: str) -> str:
    return "on" + role[0].upper() + role[1:]


def test_built_ins_are_complete_role_sets():
    assert set(THEMES) == set(BUILT_INS)
    for theme_id, theme in THEMES.items():
        assert set(theme["palette"]) == set(ROLES) | set(OPTIONAL_ROLES), theme_id
        assert len(theme["terminal"]) == 16, theme_id
        assert theme["mode"] in ("dark", "light"), theme_id


def test_amendment_3_values():
    night = THEMES["hornero-signal-night"]["palette"]
    day = THEMES["hornero-signal-day"]["palette"]
    assert (night["ruleStrong"], night["glow"], night["ink"]) == ("#8393A6", "#FFC06B", "#E6EBF1")
    assert (day["ruleStrong"], day["signal"], day["cue"], day["focus"], day["phosphor"],
            day["alert"], day["glow"]) == (
        "#7A8798", "#864700", "#145D86", "#145D86", "#1E6448", "#9C293E", "#864700")
    high = THEMES["hornero-signal-contrast"]["palette"]
    assert high["glow"] == high["signal"]


def test_optional_glow_falls_back_to_signal():
    src = (ROOT / "services" / "Signal.qml").read_text()
    assert '"glow": "signal"' in src
    assert "target[role] = palette[role] || palette[fallback];" in src


def test_rfc_flagship_values():
    night = THEMES["hornero-signal-night"]["palette"]
    day = THEMES["hornero-signal-day"]["palette"]
    assert (night["ground"], night["ink"], night["signal"], night["cue"]) == (
        "#0C1016", "#E6EBF1", "#F2AC52", "#8BCEF0")
    assert (day["ground"], day["ink"]) == ("#E8EDF4", "#283344")
    high = THEMES["hornero-signal-contrast"]["palette"]
    assert (high["ground"], high["ink"], high["signal"], high["cue"], high["ruleStrong"]) == (
        "#000000", "#FFFFFF", "#FFC247", "#8FD3FF", "#FFFFFF")


def test_first_frame_defaults_are_signal_night():
    defaults = palette_defaults()
    for role, value in THEMES["hornero-signal-night"]["palette"].items():
        assert defaults[role].upper() == value.upper(), role


def test_ink_meets_aa_on_every_surface():
    for theme_id, theme in THEMES.items():
        p = theme["palette"]
        for fg in ("ink", "inkMuted"):
            for bg in SURFACES:
                assert contrast(p[fg], p[bg]) >= 4.5, (theme_id, fg, bg, contrast(p[fg], p[bg]))


def test_accent_text_meets_aa_on_every_surface():
    # Includes sunken input wells and lifted tooltips (amendment 2).
    for theme_id, theme in THEMES.items():
        p = theme["palette"]
        for fg in ACCENTS + ("glow",):
            for bg in SURFACES:
                assert contrast(p[fg], p[bg]) >= 4.5, (theme_id, fg, bg, contrast(p[fg], p[bg]))


def test_paired_on_roles_meet_aa():
    for theme_id, theme in THEMES.items():
        p = theme["palette"]
        for role in ACCENTS:
            for fill in (role, f"{role}Well"):
                fg = _on(fill)
                assert contrast(p[fg], p[fill]) >= 4.5, (theme_id, fg, fill)
        assert contrast(p["onInverse"], p["inverse"]) >= 4.5, theme_id
        assert contrast(p["inverseSignal"], p["inverse"]) >= 4.5, theme_id


def test_boundaries_and_focus_meet_nontext_aa():
    for theme_id, theme in THEMES.items():
        p = theme["palette"]
        for bg in ("base", "panel", "lifted"):
            ratio = contrast(p["ruleStrong"], p[bg])
            assert ratio >= 3.0, (theme_id, "ruleStrong", bg, ratio)
        for bg in SURFACES:
            ratio = contrast(p["focus"], p[bg])
            assert ratio >= 3.0, (theme_id, "focus", bg, ratio)


def test_rule_strong_is_never_text_colour():
    for rel in ("components/SectionHeader.qml", "components/PropertyRow.qml",
                "modules/controlcenter/components/SliderInput.qml"):
        src = (ROOT / rel).read_text()
        assert "color: Signal.palette.ruleStrong\n" not in src, rel


def test_pluginkit_essential_borders_use_rule_strong():
    """Control boundaries reach 3:1 (RFC §3.1 `ruleStrong`); panel and well
    edges inside a surface use the quieter `rule` (visual language §7.1)."""
    kit = ROOT / "plugin/qml/Hornero/PluginKit"
    for name in ("UiTooltip.qml", "UiSlider.qml", "UiToggle.qml", "UiButton.qml"):
        assert "Theme.palette.ruleStrong" in (kit / name).read_text(), name
    for name in ("UiPopover.qml", "UiCard.qml", "UiWell.qml", "UiScope.qml"):
        assert "border.color: Theme.palette.rule" in (kit / name).read_text(), name


def test_frame_edge_separates_bar_from_ground_in_high_contrast():
    """shell#515: under Signal Contrast the bar fill (`base`) sits ~1.07:1 from
    `ground`, so the boundary is carried by an edge stroke (modules/drawers/
    Border.qml). In High Contrast that stroke uses `ruleStrong` and must reach
    3:1 (SC 1.4.11) against both the bar fill and the ground."""
    p = THEMES["hornero-signal-contrast"]["palette"]
    assert contrast(p["base"], p["ground"]) < 1.5  # the fill alone cannot separate
    for bg in ("base", "ground"):
        assert contrast(p["ruleStrong"], p[bg]) >= 3.0, bg
    for theme_id, theme in THEMES.items():
        q = theme["palette"]
        assert contrast(q["rule"], q["base"]) >= 1.2, theme_id  # quiet edge stays visible


def test_frame_edge_is_drawn_and_customisable():
    border = (ROOT / "modules" / "drawers" / "Border.qml").read_text()
    assert "border.width: strokeWidth" in border
    assert "hc ? Signal.palette.ruleStrong : Signal.palette.rule" in border
    assert "Math.max(2, Config.border.edgeWidth)" in border
    section = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "BorderSection.qml").read_text()
    assert 'key: "edgeWidth"' in section
    assert "property int edgeWidth: 1" in (ROOT / "config" / "BorderConfig.qml").read_text()
