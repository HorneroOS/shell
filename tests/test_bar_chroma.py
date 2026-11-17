"""Bar chromatic discipline: ink + muted ink + one amber accent (shell#529, #530)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPONENTS = ROOT / "modules/bar/components"
# Roles that make a bar rainbow: data (phosphor) and cue (cyan) never colour a
# bar foreground by default. Special workspaces keep phosphor for their own marker.
ALLOWED_PHOSPHOR = {"SpecialWorkspaces.qml"}


def test_bar_components_do_not_tint_with_phosphor_or_cue():
    offenders = []
    for path in COMPONENTS.rglob("*.qml"):
        src = path.read_text(encoding="utf-8")
        if re.search(r"palette\.(phosphor|cue)\b", src) and path.name not in ALLOWED_PHOSPHOR:
            offenders.append(path.name)
    assert offenders == []


def test_clock_is_one_colour_and_power_is_not_red_at_rest():
    clock = (COMPONENTS / "Clock.qml").read_text(encoding="utf-8")
    assert "property color colour: root.tone.ink" in clock
    power = (COMPONENTS / "Power.qml").read_text(encoding="utf-8")
    assert "color: root.tone.alert" not in power


def test_slider_thumb_is_ink_until_dragged():
    src = (COMPONENTS / "InlineSlider.qml").read_text(encoding="utf-8")
    assert "thumbColour: slider.pressed ? root.tone.signal : root.tone.ink" in src


def test_mark_defaults_to_the_hornero_mark_in_signal():
    cfg = json.loads((ROOT / "config/shell.default.json").read_text(encoding="utf-8"))
    assert cfg["bar"]["mark"] == "hornero"
    icon = (COMPONENTS / "OsIcon.qml").read_text(encoding="utf-8")
    assert "assets/mark.svg" in icon and "Signal.palette.signal" in icon
    assert (ROOT / "assets/mark.svg").is_file()


def test_tray_and_extension_icons_are_monochrome_by_default():
    cfg = json.loads((ROOT / "config/shell.default.json").read_text(encoding="utf-8"))
    assert cfg["bar"]["tray"]["recolour"] is True
    assert cfg["bar"]["extensions"]["recolour"] is True


def test_clear_sliders_use_a_rule_track_not_capsules():
    slider = (ROOT / "components/controls/StyledSlider.qml").read_text(encoding="utf-8")
    assert "property bool ruleTrack: false" in slider
    assert slider.count("root.ruleTrack ? 0") >= 4
    inline = (COMPONENTS / "InlineSlider.qml").read_text(encoding="utf-8")
    assert "ruleTrack: root.tone.active" in inline
