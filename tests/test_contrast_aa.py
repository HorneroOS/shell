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


def test_amendment_2_values():
    night = THEMES["hornero-signal-night"]["palette"]
    day = THEMES["hornero-signal-day"]["palette"]
    assert (night["ruleStrong"], night["glow"]) == ("#707A85", "#FFB650")
    assert (day["ruleStrong"], day["signal"], day["cue"], day["focus"], day["phosphor"],
            day["alert"], day["glow"]) == (
        "#736D62", "#8F4B00", "#1A5F88", "#1A5F88", "#256A3B", "#A8341C", "#8F4B00")
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
        "#0C0F13", "#ECE6DA", "#F2A33A", "#7EC1EA")
    assert (day["ground"], day["ink"]) == ("#E6E1D5", "#1B1E22")
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
        for fg in ("ruleStrong", "focus"):
            for bg in SURFACES:
                ratio = contrast(p[fg], p[bg])
                assert ratio >= 3.0, (theme_id, fg, bg, ratio)


def test_rule_strong_is_never_text_colour():
    for rel in ("components/SectionHeader.qml", "components/PropertyRow.qml",
                "modules/controlcenter/components/SliderInput.qml"):
        src = (ROOT / rel).read_text()
        assert "color: Signal.palette.ruleStrong\n" not in src, rel


def test_pluginkit_essential_borders_use_component_border():
    kit = ROOT / "plugin/qml/Hornero/PluginKit"
    assert "componentBorder: Signal.palette.ruleStrong" in (kit / "Theme.qml").read_text()
    for name in ("UiTooltip.qml", "UiPopover.qml"):
        src = (kit / name).read_text()
        assert "border.color: Theme.componentBorder" in src, name
        assert "border.color: Theme.outlineVariant" not in src, name
    for name in ("UiSlider.qml", "UiProgress.qml", "UiChip.qml"):
        assert "border.color: Theme.componentBorder" in (kit / name).read_text(), name
