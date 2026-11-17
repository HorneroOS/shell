"""Cockpit Clear adaptive ink (signal-visual-language §12, RFC 0001 §5.1).

The model (services/clearink.js) runs under node; the sampler
(components/clearink/ClearInkField.qml) runs for real under the Qt qml
runtime with QT_QPA_PLATFORM=offscreen against a generated wallpaper.
Static contracts pin that a clear bar paints no background at all.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import zlib
from pathlib import Path

import pytest

from signal_tokens import built_in_themes, contrast as hex_contrast

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "clearink.js"
BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
FIELD = ROOT / "components" / "clearink" / "ClearInkField.qml"


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/clearink.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


# --- Model -------------------------------------------------------------------

def test_polarity_roles_mirror_the_signal_night_and_day_themes():
    out = run_js("return {light: LIGHT, dark: DARK}")
    themes = built_in_themes()
    night = themes["hornero-signal-night"]["palette"]
    day = themes["hornero-signal-day"]["palette"]
    for role in ("ink", "inkMuted", "alert"):
        assert out["light"][role].lower() == night[role].lower(), role
        assert out["dark"][role].lower() == day[role].lower(), role
    assert out["light"]["signal"].lower() == night["glow"].lower()
    assert out["dark"]["signal"].lower() == day["signal"].lower()
    assert out["light"]["halo"].lower() == night["ground"].lower()
    assert out["dark"]["halo"].lower() == "#ffffff"


@pytest.mark.parametrize("mean,polarity", [(0.02, "light"), (0.9, "dark"), (0.0, "light"), (1.0, "dark")])
def test_polarity_follows_the_larger_contrast(mean, polarity):
    out = run_js(f"return toneFor({{mean: {mean}, dev: 0.02}}, 'auto', false).polarity")
    assert out == polarity


def test_auto_is_a_hairline_rim_plus_soft_shadow_never_a_sticker_outline():
    flat = run_js("return toneFor({mean: 0.05, dev: 0.02}, 'auto', false)")
    busy = run_js("return toneFor({mean: 0.05, dev: 0.2}, 'auto', false)")
    assert flat["haloPx"] == 1 and flat["haloAlpha"] == 0.5
    assert flat["shadowPx"] == 3 and flat["shadowAlpha"] == pytest.approx(0.62)
    assert busy["shadowPx"] == 4 and busy["shadowAlpha"] == pytest.approx(0.74)  # deviation > 0.12
    # No style may bring back the old 3 px near-opaque ring.
    for style in ("auto", "outline", "shadow", "contrast"):
        t = run_js(f"return toneFor({{mean: 0.5, dev: 0.3}}, '{style}', false)")
        assert t["haloPx"] <= 2 and (t["haloPx"] == 0 or t["haloAlpha"] > 0), style


def test_foreground_styles():
    t = lambda style, mean=0.05: run_js(  # noqa: E731
        f"return toneFor({{mean: {mean}, dev: 0.3}}, '{style}', false)")
    assert (t("outline")["haloPx"], t("outline")["shadowPx"]) == (1.5, 0)
    assert (t("shadow")["haloPx"], t("shadow")["shadowPx"]) == (0, 4)
    contrast = t("contrast")
    assert (contrast["haloPx"], contrast["shadowPx"], contrast["weight"]) == (2, 3, 600)
    assert t("bogus")["style"] == "auto"


def test_knobs_scale_the_halo_and_can_switch_it_off():
    base = run_js("return toneFor({mean: 0.05, dev: 0.02}, 'auto', false)")
    weak = run_js("return toneFor({mean: 0.05, dev: 0.02}, 'auto', false, null, {strength: 0.5, outline: 2})")
    assert weak["shadowAlpha"] == pytest.approx(base["shadowAlpha"] * 0.5)
    assert weak["haloPx"] == pytest.approx(base["haloPx"] * 2)
    off = run_js("return effectParams(toneFor({mean: 0.05, dev: 0.02}, 'auto', false, null, {strength: 0}))")
    assert off["enabled"] is False


def test_forced_polarity_overrides_the_wallpaper():
    light = run_js("return toneFor({mean: 1, dev: 0}, 'auto', false, null, {polarity: 'light'}).polarity")
    dark = run_js("return toneFor({mean: 0, dev: 0}, 'auto', false, null, {polarity: 'dark'}).polarity")
    assert (light, dark) == ("light", "dark")


def test_auto_keeps_the_theme_polarity_on_dark_and_flips_on_bright_regions():
    night = lambda m: run_js(f"return toneFor({{mean: {m}, dev: 0.02}}, 'auto', false).polarity")  # noqa: E731
    day = lambda m: run_js(f"return toneFor({{mean: {m}, dev: 0.02}}, 'auto', true).polarity")  # noqa: E731
    assert night(0.1) == "light" and night(0.7) == "dark"
    assert day(0.9) == "dark" and day(0.01) == "light"


def test_unknown_wallpaper_follows_theme_and_keeps_every_cue():
    night = run_js("return toneFor(null, 'auto', false)")
    day = run_js("return toneFor(null, 'auto', true)")
    assert (night["polarity"], day["polarity"]) == ("light", "dark")
    assert night["known"] is False and night["shadowPx"] == 4 and night["shadowAlpha"] > 0


def test_grid_and_region_stats_split_a_two_tone_wallpaper():
    out = run_js(
        "const cols = 192, rows = 108, px = [];"
        "for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {"
        "  const v = x < cols / 2 ? 0 : 255; px.push(v, v, v, 255); }"
        "const g = buildGrid(px, cols, rows);"
        "return {left: regionStats(g, {x: 100, y: 10, width: 200, height: 30}, 1920, 1080, 2),"
        "        right: regionStats(g, {x: 1500, y: 10, width: 200, height: 30}, 1920, 1080, 2),"
        "        straddle: regionStats(g, {x: 900, y: 10, width: 120, height: 30}, 1920, 1080, 2),"
        "        none: regionStats(null, {x: 0, y: 0, width: 5, height: 5}, 1920, 1080, 2),"
        "        short: buildGrid([0, 0, 0, 255], cols, rows)}"
    )
    assert out["left"]["mean"] == 0 and out["left"]["dev"] == 0
    assert out["right"]["mean"] == pytest.approx(1.0)
    # A glyph straddling the edge has a large deviation: busy region.
    assert out["straddle"]["dev"] > 0.3
    assert out["none"] is None and out["short"] is None


def test_cover_rect_and_grid_rows():
    out = run_js(
        "return {wide: coverRect(2000, 1000, 16, 9), tall: coverRect(1000, 2000, 16, 9),"
        " rows: rowsFor(1920, 1080), rowsUltra: rowsFor(3440, 1440), none: rowsFor(0, 10)}"
    )
    assert out["wide"]["width"] == pytest.approx(1000 * 16 / 9)
    assert out["tall"]["height"] == pytest.approx(1000 * 9 / 16)
    assert out["rows"] == 108 and out["rowsUltra"] == 80 and out["none"] == 0


def test_effect_params_describe_a_glyph_shadow_not_a_box():
    flat = run_js("return effectParams(toneFor({mean: 0.05, dev: 0.02}, 'auto', false))")
    assert flat["enabled"] and flat["outlinePx"] == 1 and flat["shadowPx"] == 3
    assert flat["pad"] >= flat["shadowPx"] + flat["shadowDy"] + 1  # the shadow never clips
    off = run_js("return effectParams({haloPx: 0, shadowPx: 0, haloAlpha: 0.5})")
    assert off["enabled"] is False


# --- A clear bar draws no background ------------------------------------------

def test_clear_bar_has_no_scrim_tint_slab_or_island_shadow():
    assert "id: scrim" not in BAR
    assert "Edge scrim" not in BAR
    assert "shadowColor: Signal.palette.base" not in BAR
    # The only background slab stays hidden for clear bars.
    assert re.search(r"visible: !root\.clear && \(root\.floating", BAR)


def test_clear_foreground_groups_paint_no_fill():
    ws = (ROOT / "modules/bar/components/workspaces/Workspaces.qml").read_text()
    assert 'color: labels || clear ? "transparent"' in ws
    assert "!root.clear" in ws  # no occupied backdrop pills
    active = (ROOT / "modules/bar/components/workspaces/ActiveIndicator.qml").read_text()
    assert 'root.clear ? "transparent"' in active
    status = (ROOT / "modules/bar/components/StatusIcons.qml").read_text()
    assert 'color: clear ? "transparent"' in status
    assert "!root.tone.active" in (ROOT / "modules/bar/components/Clock.qml").read_text()


def test_halo_is_a_glyph_silhouette_shadow_per_entry():
    assert "visible: root.clear && wrapped.item !== null && halo.fx.enabled" in BAR
    assert "clearinkhalo.frag.qsb" in BAR
    assert "MultiEffect" not in BAR
    assert (ROOT / "assets/shaders/clearinkhalo.frag.qsb").is_file()


def test_popouts_stay_opaque():
    surface = (ROOT / "components" / "placement" / "AnchoredSurface.qml").read_text()
    assert "property color fill: Signal.palette.panel" in surface
    assert "elementAlpha" not in surface and "tPalette" not in surface


def test_high_contrast_forces_the_contrast_style():
    ink = (ROOT / "services" / "ClearInk.qml").read_text()
    assert 'Config.appearance.highContrast ? "contrast"' in ink


def test_clear_style_is_configured_and_selectable():
    cfg = (ROOT / "config" / "BarConfig.qml").read_text()
    assert 'property string clearStyle: "auto"' in cfg
    assert json.loads((ROOT / "config" / "shell.default.json").read_text())["bar"]["clearStyle"] == "auto"
    row = (ROOT / "modules" / "layoutpicker" / "ClearStyleRow.qml").read_text()
    assert "SegmentedControl" in row
    assert "ClearStyleRow" in (ROOT / "modules/layoutpicker/Content.qml").read_text()
    assert "ClearStyleRow" in (ROOT / "modules/controlcenter/layout/LayoutPane.qml").read_text()


# --- The sampler, for real (offscreen Qt) -------------------------------------

def _png(path: Path, width: int, height: int, pixel) -> None:
    raw = b"".join(
        b"\x00" + b"".join(bytes(pixel(x, y)) for x in range(width)) for y in range(height)
    )

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


@pytest.mark.skipif(not shutil.which("qml6"), reason="NOT RUN: Qt qml6 runtime not available")
def test_sampler_reads_a_real_wallpaper_and_picks_per_region_polarity(tmp_path):
    wall = tmp_path / "wall.png"
    # Left half black, right half white; 2:1 image covers a 16:9 screen.
    _png(wall, 128, 64, lambda x, y: (0, 0, 0) if x < 64 else (255, 255, 255))
    qml = tmp_path / "probe.qml"
    qml.write_text(f"""
import QtQuick
import "file://{ROOT}/components/clearink"
import "file://{ROOT}/services/clearink.js" as Model

Item {{
    width: 1920; height: 1080
    ClearInkField {{ id: field; screenWidth: 1920; screenHeight: 1080; source: "{wall}" }}
    Item {{ id: onBlack; x: 100; y: 10; width: 200; height: 30 }}
    Item {{ id: onWhite; x: 1500; y: 10; width: 200; height: 30 }}
    Timer {{
        interval: 100; repeat: true; running: true
        property int tries: 0
        onTriggered: {{
            tries++;
            if (!field.ready && tries < 80) return;
            const l = Model.toneFor(field.statsFor(onBlack), "auto", false);
            const r = Model.toneFor(field.statsFor(onWhite), "auto", false);
            console.log("RESULT " + JSON.stringify({{ready: field.ready, left: l.polarity, right: r.polarity,
                leftKnown: l.known, rows: field.rows}}));
            Qt.quit();
        }}
    }}
}}
""")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_FORCE_STDERR_LOGGING="1",
               QT_QUICK_BACKEND="software")
    proc = subprocess.run(["qml6", str(qml)], capture_output=True, text=True, timeout=60, env=env)
    line = next((ln for ln in (proc.stdout + proc.stderr).splitlines() if "RESULT" in ln), None)
    assert line, proc.stdout + proc.stderr
    got = json.loads(line.split("RESULT ", 1)[1])
    assert got == {"ready": True, "left": "light", "right": "dark", "leftKnown": True, "rows": 108}
