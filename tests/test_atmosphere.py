"""Atmosphere layer (visual language section 17): user-tunable, bounded,
guarded, contrast-safe, and wired into the first-party surfaces."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from signal_tokens import SURFACES, built_in_themes, contrast  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "atmosphere.js"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/atmosphere.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


# --- model ------------------------------------------------------------------

def test_factory_defaults_agree_everywhere():
    factory = json.loads(_read("config/shell.default.json"))["appearance"]["atmosphere"]
    assert run_js("return DEFAULTS;") == factory
    qml = _read("config/AppearanceConfig.qml").split("component Atmosphere: JsonObject {", 1)[1].split("}", 1)[0]
    props = dict(re.findall(r"property \w+ (\w+): (\"?[\w.]+\"?)", qml))
    assert {k: json.loads(v) for k, v in props.items()} == factory
    section = _read("modules/controlcenter/appearance/sections/AtmosphereSection.qml")
    block = section.split("readonly property var factory: ({", 1)[1].split("})", 1)[0]
    assert {k: json.loads(v) for k, v in re.findall(r'"(\w+)": ("?[\w.]+"?)', block)} == factory
    look = _read("modules/controlcenter/appearance/sections/LookSection.qml")
    hornero = re.search(r'id: "hornero".*?atmosphere: \(\{(.*?)\}\)', look, re.S).group(1)
    # A look never flips the on/off switch (the user's own choice).
    assert {k: json.loads(v) for k, v in re.findall(r"(\w+): (\"?[\w.]+\"?)", hornero)} == {k: v for k, v in factory.items() if k != "enabled"}


def test_clean_clamps_and_falls_back():
    out = run_js('return clean({lamp: 9, warmth: -3, grain: "x", tone: "loud", mascot: "yes", enabled: 0});')
    assert out["lamp"] == 1.5 and out["warmth"] == 0 and out["grain"] == 0.3
    assert out["tone"] == "cozy" and out["mascot"] is False and out["enabled"] is False
    assert run_js("return clean(null);") == run_js("return DEFAULTS;")


DUSK = {"ground": "#14100F", "sunken": "#1A1514", "base": "#201A19", "panel": "#27201E", "raised": "#302826",
        "lifted": "#3B312E", "ink": "#F1E6D2", "glow": "#FFB070", "signal": "#F29A4A", "alert": "#F2705E",
        "term5": "#D98FC0"}


def test_dusk_chips_and_alert_text_are_legible_on_every_surface():
    # Dusk alert is 4.36:1 on `lifted` (tooltips); alertText is the legible pairing.
    assert contrast(DUSK["alert"], DUSK["lifted"]) < 4.5
    chips = run_js(f"return chips({json.dumps(DUSK)}, 0.2);")
    for name, colour in chips.items():
        for s in SURFACES:
            assert contrast(colour, DUSK[s]) >= 4.5, (name, s)
    tip = _read("components/controls/Tooltip.qml")
    assert "Atmosphere.alertText" in tip


def test_low_power_drops_everything_but_the_inner_highlight():
    lv = run_js("return levels({vignette: 1, grain: 1, scanlines: 1, lamp: 1, innerLight: 1}, false, true);")
    assert lv["lamp"] == lv["vignette"] == lv["grain"] == lv["scanlines"] == 0 and lv["innerLight"] > 0
    assert "PowerProfile.PowerSaver" in _read("services/Atmosphere.qml")


def test_lamp_fades_400_to_600_ms_and_is_instant_when_reduced_or_low_power():
    atm = _read("services/Atmosphere.qml")
    assert "lowPower ? 0 : Appearance.anim.durations.scan" in atm
    assert 400 <= 480 <= 600  # durations.scan = round(480 * k); k = 0 under reduced motion
    assert '"scan": Math.round(480 * motion._k)' in _read("config/Appearance.qml")
    assert "duration: Atmosphere.fadeMs" in _read("components/atmosphere/AtmosphereLayer.qml")
    assert "root.shown || root.opacity > 0" in _read("components/atmosphere/AtmosphereLayer.qml")


def test_cozy_look_keeps_effective_radii_inside_the_amendment_ceiling():
    look = _read("modules/controlcenter/appearance/sections/LookSection.qml")
    scale = float(re.search(r'id: "cozy".*?rounding: ([\d.]+)', look, re.S).group(1))
    assert 3 * scale <= 6 and 5 * scale <= 6.01, "small x 2 ceiling (no pill drift)"


def test_atmosphere_never_touches_bars_so_cockpit_clear_stays_untinted():
    for path in ROOT.glob("modules/bar/**/*.qml"):
        text = path.read_text()
        assert "AtmosphereLayer" not in text and "AtmosphereTexture" not in text, path


def test_plate_component_is_an_engraved_enum_label():
    src = _read("components/Plate.qml")
    for needle in ("Font.AllUppercase", "tabular: true", "Font.DemiBold", "Atmosphere.plateTracking",
                   "appearance.display" if False else "Appearance.font.family.display"):
        assert needle in src, needle
    assert "font.letterSpacing: root.size * root.tracking" in src  # no font.pointSize read: no binding loop
    assert "Plate {" in _read("modules/launcher/Content.qml")


def test_alphas_have_hard_ceilings():
    lv = run_js("return levels({lamp: 99, innerLight: 99, vignette: 99, grain: 99, scanlines: 99}, false);")
    assert lv["lamp"] <= 0.20 and lv["innerLight"] <= 0.10 and lv["vignette"] <= 0.30
    assert lv["grain"] <= 0.14 and lv["scanlines"] <= 0.06


def test_disabled_and_day_rules():
    off = run_js("return levels({enabled: false}, false);")
    assert off["enabled"] is False and not any(off[k] for k in ("lamp", "innerLight", "vignette", "grain", "scanlines"))
    day = run_js("return levels({vignette: 1, scanlines: 1}, true);")
    night = run_js("return levels({vignette: 1, scanlines: 1}, false);")
    assert day["vignette"] == 0 and day["scanlines"] == 0
    assert night["vignette"] > 0 and night["scanlines"] > 0
    assert day["lamp"] < night["lamp"]


@pytest.mark.parametrize("theme_id", ["hornero-signal-night", "hornero-signal-day", "hornero-signal-contrast"])
@pytest.mark.parametrize("warmth", [0, 0.5, 1])
def test_chips_meet_aa_on_every_surface(theme_id, warmth):
    theme = built_in_themes()[theme_id]
    pal = dict(theme["palette"])
    pal["term5"] = theme["terminal"][5]
    chips = run_js(f"return chips({json.dumps(pal)}, {warmth});")
    for name, colour in chips.items():
        for surface in SURFACES:
            assert contrast(colour, pal[surface]) >= 4.5, (theme_id, warmth, name, surface)


def test_chips_follow_custom_palettes_and_warmth():
    pal = {"ground": "#101010", "sunken": "#141414", "base": "#181818", "panel": "#1C1C1C",
           "raised": "#202020", "lifted": "#242424", "ink": "#F0F0F0", "glow": "#33AAFF",
           "signal": "#33AAFF", "alert": "#FF4466", "term5": "#AA66FF"}
    a = run_js(f"return chips({json.dumps(pal)}, 0);")
    b = run_js(f"return chips({json.dumps(pal)}, 1);")
    assert a["lamp"] != b["lamp"] and b["lamp"] == b["blush"]


# --- guards and budget ------------------------------------------------------

def test_service_guards_modes_and_high_contrast():
    src = _read("services/Atmosphere.qml")
    for needle in ("Config.appearance.highContrast", "Experience.focus", "Experience.gaming", "Experience.studio",
                   "Signal.light"):
        assert needle in src, needle
    assert "settings.enabled && allowed" in src


def test_layer_spends_glow_budget_and_never_takes_input():
    src = _read("components/atmosphere/AtmosphereLayer.qml")
    assert "Experience.acquireGlow(root, 1)" in src and "Experience.releaseGlow(root)" in src
    assert "Component.onDestruction" in src
    assert "enabled: false" in src and "Accessible.ignored: true" in src
    assert "z: -" not in src
    assert "MouseArea" not in src


def test_texture_sits_under_content_and_layer_over_it():
    # Grain/scanlines must be the FIRST child (behind text), the veil the LAST.
    for rel in ("modules/launcher/Content.qml", "modules/dashboard/Content.qml", "modules/osd/Content.qml",
                "modules/lock/Content.qml", "modules/session/Wrapper.qml", "modules/welcome/Window.qml"):
        text = _read(rel)
        assert "AtmosphereTexture {}" in text, rel
        assert text.index("AtmosphereTexture {}") < text.index("AtmosphereLayer {") if "AtmosphereLayer {" in text else True
    tex = _read("components/atmosphere/AtmosphereTexture.qml")
    assert "enabled: false" in tex and "Accessible.ignored: true" in tex and "Atmosphere.active" in tex
    assert "grain" not in _read("components/atmosphere/AtmosphereLayer.qml").split("Item {", 1)[1]


def test_layer_is_not_forced_negative_z_on_surfaces():
    # A negative z paints the layer behind the parent (and behind panel fills).
    for path in ROOT.glob("modules/**/*.qml"):
        text = path.read_text()
        if "AtmosphereLayer {" in text:
            block = text.split("AtmosphereLayer {", 1)[1].split("}", 1)[0]
            assert "z: -" not in block, path


# --- surfaces ---------------------------------------------------------------

SURFACES_WITH_LAYER = (
    "modules/launcher/Content.qml", "modules/dashboard/Content.qml", "modules/osd/Content.qml",
    "modules/session/Wrapper.qml", "modules/notifications/Notification.qml", "modules/lock/Content.qml",
    "modules/welcome/Window.qml", "modules/controlcenter/ControlCenter.qml", "modules/controlcenter/WindowTitle.qml",
)


@pytest.mark.parametrize("rel", SURFACES_WITH_LAYER)
def test_first_party_surfaces_carry_the_layer(rel):
    text = _read(rel)
    assert "AtmosphereLayer {" in text and "import qs.components.atmosphere" in text


def test_notification_cards_spend_no_lamp():
    block = _read("modules/notifications/Notification.qml").split("AtmosphereLayer {", 1)[1].split("}", 1)[0]
    assert "lamp: false" in block and "innerLight: !root.critical" in block


# --- mascot and microcopy ---------------------------------------------------

def test_sprite_grid_is_rectangular_and_uses_known_cells():
    src = _read("components/atmosphere/HorneroSprite.qml")
    rows = re.findall(r'^\s+"([.A-Za-z]+)",?$', src.split("readonly property var rows: [", 1)[1].split("]", 1)[0], re.M)
    assert len(rows) >= 12
    assert {len(r) for r in rows} == {16}, "every sprite row must be 16 cells"
    palette = set(re.findall(r'"(\w)": ', src.split("readonly property var palette: ({", 1)[1].split("})", 1)[0]))
    assert set("".join(rows)) - {"."} <= palette
    assert "Accessible.ignored: true" in src
    assert "Appearance.anim.reduced" in src, "blinking must stop under reduced motion"


def _table(name: str) -> dict:
    src = _read("services/Microcopy.qml")
    block = src.split(f"readonly property var {name}: ({{", 1)[1].split("})", 1)[0]
    return dict(re.findall(r'"([\w.]+)": qsTr\("([^"]*)"\)', block))


def test_microcopy_voices_define_the_same_keys():
    plain, warm = _table("plain"), _table("warm")
    assert plain and set(plain) == set(warm)


def test_microcopy_tone_rules():
    for key, text in _table("warm").items():
        assert len(text) <= 48, (key, text)
        assert "!" not in text and "?" not in text, (key, text)
        assert text.isascii(), (key, text)
        assert not re.search(r"[:;=]['\-]?[()DPp3<>]|\^_\^|\bUwU\b|<3", text), (key, text)
    for text in _table("plain").values():
        assert "!" not in text


def test_every_microcopy_key_is_used():
    keys = set(_table("plain"))
    corpus = "\n".join(p.read_text() for p in ROOT.glob("modules/**/*.qml"))
    for key in keys:
        if key.startswith("greeting."):
            assert "Microcopy.greeting" in corpus
        else:
            assert f'Microcopy.line("{key}")' in corpus, key


# --- controls ---------------------------------------------------------------

def test_every_knob_has_a_control_and_search_entry():
    section = _read("modules/controlcenter/appearance/sections/AtmosphereSection.qml")
    keys = set(json.loads(_read("config/shell.default.json"))["appearance"]["atmosphere"])
    for key in keys - {"enabled", "mascot", "tone"}:  # incl. plateTracking
        assert f'key: "{key}"' in section, key
    assert "root.atmo.enabled = checked" in section and "root.atmo.mascot = checked" in section
    assert "root.atmo.tone = modelData.id" in section
    assert "resetAll" in section
    pane = _read("modules/controlcenter/appearance/AppearancePane.qml")
    assert "AtmosphereSection {" in pane and 'isSectionExpanded("atmosphere")' in pane
    assert 'id: "atmosphere"' in _read("modules/controlcenter/PaneRegistry.qml")


def test_cozy_look_sets_the_atmosphere():
    look = _read("modules/controlcenter/appearance/sections/LookSection.qml")
    assert "Config.appearance.atmosphere[k] = look.atmosphere[k]" in look
    cozy = re.search(r'id: "cozy".*?atmosphere: \(\{(.*?)\}\)', look, re.S).group(1)
    vals = {k: json.loads(v) for k, v in re.findall(r"(\w+): (\"?[\w.]+\"?)", cozy)}
    cfg = run_js("return clean(" + json.dumps(vals) + ");")
    for k in ("lamp", "warmth", "innerLight", "vignette", "grain", "scanlines"):
        assert cfg[k] == vals[k], f"cozy {k} outside slider range"
    assert vals["lamp"] > 0.8 and vals["tone"] == "cozy"


# --- assets and type --------------------------------------------------------

def test_assets_are_png_and_regenerable():
    for name in ("grain.png", "scanlines.png"):
        assert (ROOT / "assets" / "atmosphere" / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    assert (ROOT / "scripts" / "build-atmosphere-assets.py").is_file()


def test_styled_text_exposes_tabular_numerals_and_tracking():
    src = _read("components/StyledText.qml")
    assert "property bool tabular: false" in src and '"tnum": 1' in src
    assert "letterSpacing" in _read("modules/lock/Center.qml")
    assert "tabular: true" in _read("modules/instruments/Readout.qml")


def test_live_numeric_readouts_use_tabular_figures():
    """R-082: values that change while on screen never shift their
    neighbours; each reads with OpenType tnum (StyledText.tabular)."""
    for rel, needle in (
        ("modules/bar/popouts/BatteryGauge.qml", "tabular: true"),
        ("modules/bar/popouts/Audio.qml", "tabular: true"),
        ("modules/controlcenter/components/ReadonlySlider.qml", "tabular: true"),
        ("modules/dashboard/weather/HourlyChart.qml", "tabular: true"),
        ("modules/utilities/cards/IdleInhibit.qml", "tabular: true"),
        ("modules/background/DesktopClock.qml", "tabular: true"),
    ):
        assert needle in _read(rel), rel
