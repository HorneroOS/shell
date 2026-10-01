"""Per-surface transparency contract.

`appearance.transparency.elements` maps surface keys to alpha overrides
(missing/non-numeric follows the global base). This pins the full chain:
schema + serializer + factory default, Colours helpers, control-center UI,
and one consumer call per surface so no slider is dead."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ELEMENTS = {
    "bar",
    "launcher",
    "dashboard",
    "session",
    "sidebar",
    "utilities",
    "notifications",
    "osd",
    "lock",
    "layoutpicker",
}


def test_schema_has_elements_map():
    src = (ROOT / "config" / "AppearanceConfig.qml").read_text()
    assert re.search(r"property var elements:\s*\(\{\}\)", src), (
        "Transparency schema must declare `property var elements: ({})`"
    )


def test_serializer_and_factory_cover_elements():
    config_src = (ROOT / "config" / "Config.qml").read_text()
    assert "elements: appearance.transparency.elements" in config_src, (
        "serializeAppearance must persist transparency.elements"
    )
    factory = json.loads((ROOT / "config" / "shell.default.json").read_text())
    assert factory["appearance"]["transparency"]["elements"] == {}, (
        "factory default must ship transparency.elements as {}"
    )


def test_colours_helpers():
    src = (ROOT / "services" / "Colours.qml").read_text()
    assert "function elementAlpha(element: string): real" in src
    assert "function surface(c: color, element: string): color" in src
    assert "readonly property var elements: Appearance.transparency.elements" in src


def test_ui_lists_every_element():
    section = (
        ROOT
        / "modules"
        / "controlcenter"
        / "appearance"
        / "sections"
        / "TransparencySection.qml"
    ).read_text()
    for el in ELEMENTS:
        assert f'key: "{el}"' in section, f"TransparencySection missing slider for {el}"
    pane = (
        ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePane.qml"
    ).read_text()
    assert "property var transparencyElements" in pane
    assert (
        "Config.appearance.transparency.elements = root.transparencyElements"
        in pane
    ), "AppearancePane.saveConfig must persist transparencyElements"


def test_every_element_has_a_consumer():
    """Each slider key must reach a surface() or elementAlpha() call site,
    otherwise the UI promises control it cannot deliver."""
    hits = {}
    for path in list((ROOT / "modules").rglob("*.qml")) + list(
        (ROOT / "services").rglob("*.qml")
    ):
        if path.name in {"TransparencySection.qml"}:
            continue
        src = path.read_text()
        for el in ELEMENTS:
            if f'"{el}"' in src and (
                "elementAlpha(" in src or "surface(" in src
            ):
                hits.setdefault(el, []).append(str(path.relative_to(ROOT)))
    missing = ELEMENTS - set(hits)
    assert not missing, f"elements without a consumer call site: {sorted(missing)}"


def test_no_window_level_opacity_double_dim():
    """The drawers container must not multiply a global opacity over
    per-surface alphas; the Border frame keeps the explicit global."""
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    assert (
        "opacity: Colours.transparency.enabled ? Colours.transparency.base : 1"
        in src
    ), "Border must keep the explicit global opacity"
    assert src.count("Colours.transparency.base") == 1, (
        "only the Border may use the raw global base as opacity"
    )
