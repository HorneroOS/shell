"""Offscreen harness for PluginKit 3 runtime tests.

Builds an import tree with the REAL PluginKit files (Theme, Ui*, internal
singletons) over small stubs of the shell modules they bind to (qs.config,
qs.services, qs.utils). The Signal palette stub carries the real Night and
Day role tables parsed from services/Signal.qml and the glyph stub loads the
real Hornero Glyphs font and name table, so offscreen renders use the same
colours and glyphs as the shell. QML-level evidence only: no compositor,
no live shell services.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"

# Kit files that only need the stubbed shell modules (no live services).
UI_FILES = [
    "Theme.qml", "ExperienceBridge.qml", "GlowBudget.qml",
    "UiText.qml", "UiEyebrow.qml", "UiIcon.qml", "UiCard.qml", "UiWell.qml",
    "UiButton.qml", "UiToggle.qml", "UiSlider.qml", "UiTextField.qml",
    "UiTextArea.qml", "UiSpinBox.qml", "UiComboBox.qml", "UiMetric.qml",
    "UiDetailRow.qml", "UiActionRow.qml", "UiChip.qml", "UiProgress.qml",
    "UiSegmentMeter.qml", "UiMeterRow.qml", "UiSparkline.qml", "UiScope.qml",
    "UiPartition.qml", "UiState.qml", "UiTooltip.qml", "UiPopover.qml",
    "UiStack.qml",
    # Shared anchored-surface solver imported by UiTooltip/UiPopover.
    "Placement.js",
]


def qmltestrunner() -> Path | None:
    runner = Path("/usr/lib/qt6/bin/qmltestrunner")
    if runner.is_file():
        return runner
    candidate = shutil.which("qmltestrunner6") or shutil.which("qmltestrunner")
    return Path(candidate) if candidate else None


def palette(theme_id: str) -> dict[str, str]:
    """Role table of a built-in theme, parsed from services/Signal.qml."""
    source = (ROOT / "services/Signal.qml").read_text(encoding="utf-8")
    start = source.index(f'"{theme_id}": {{')
    block = source[start:source.index('"terminal"', start)]
    return dict(re.findall(r'"([A-Za-z]+)": "(#[0-9A-Fa-f]{6})"', block))


def _signal_stub() -> str:
    night = palette("hornero-signal-night")
    day = palette("hornero-signal-day")
    roles = sorted(night)
    props = "\n".join(
        f'        property color {role}: stub.light ? "{day[role]}" : "{night[role]}"'
        for role in roles if not role.startswith("on")
    )
    on_props = "\n".join(
        f'        property color {role}: stub.light ? "{day[role]}" : "{night[role]}"'
        for role in roles if role.startswith("on")
    )
    return f"""pragma Singleton
import QtQuick
QtObject {{
    id: stub
    property bool light: false
    readonly property QtObject palette: Palette {{}}
    component OnRoles: QtObject {{
{on_props}
    }}
    component Palette: OnRoles {{
{props}
    }}
}}
"""


_APPEARANCE = """pragma Singleton
import QtQuick
QtObject {
    id: app
    property bool stubReduced: false
    property real stubScale: 1
    readonly property QtObject font: QtObject {
        readonly property QtObject family: QtObject {
            readonly property string sans: "IBM Plex Sans"
            readonly property string mono: "IBM Plex Mono"
            readonly property string display: "IBM Plex Sans Condensed"
        }
        readonly property QtObject size: QtObject {
            readonly property int small: 11
            readonly property int smaller: 12
            readonly property int normal: 13
            readonly property int larger: 15
            readonly property int large: 18
            readonly property int extraLarge: 28
            readonly property int display: 56
        }
    }
    readonly property QtObject rounding: QtObject {
        readonly property int small: 3
        readonly property int normal: 5
        readonly property int large: 8
        readonly property int full: 1000
    }
    readonly property QtObject spacing: QtObject {
        readonly property int small: 4
        readonly property int smaller: 8
        readonly property int normal: 12
        readonly property int larger: 16
        readonly property int large: 24
    }
    readonly property QtObject padding: QtObject {
        readonly property int small: 4
        readonly property int smaller: 6
        readonly property int normal: 8
        readonly property int larger: 12
        readonly property int large: 16
    }
    readonly property QtObject anim: QtObject {
        property string level: "standard"
        readonly property string effectiveLevel: app.stubReduced ? "off" : level
        readonly property bool reduced: app.stubReduced
        readonly property real _k: reduced ? 0 : app.stubScale
        readonly property QtObject curves: QtObject {
            readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
            readonly property list<real> enter: [0.05, 0.7, 0.1, 1, 1, 1]
            readonly property list<real> exit: [0.3, 0, 1, 1, 1, 1]
            readonly property list<real> sweep: [0.65, 0, 0.35, 1, 1, 1]
            readonly property list<real> settle: [0.32, 1.24, 0.42, 1, 1, 1]
            readonly property list<real> settleFast: [0.34, 1.3, 0.5, 1, 1, 1]
        }
        readonly property var durations: ({
            "scale": app.stubScale,
            "quick": Math.round(90 * _k), "short": Math.round(160 * _k),
            "medium": Math.round(240 * _k), "long": Math.round(360 * _k),
            "scan": Math.round(480 * _k), "settleFast": Math.round(220 * _k),
            "settle": Math.round(320 * _k), "fade": reduced ? 90 : Math.round(90 * app.stubScale)
        })
    }
}
"""

_CONFIG = """pragma Singleton
import QtQuick
QtObject {
    readonly property QtObject appearance: QtObject { property bool highContrast: false }
}
"""


def _glyph_stub() -> str:
    font = ROOT / "assets/fonts/hornero-glyphs.ttf"
    return f"""pragma Singleton
import QtQuick
import "GlyphMap.js" as GlyphMap
QtObject {{
    readonly property string family: loader.status === FontLoader.Ready ? loader.name : "Hornero Glyphs"
    readonly property FontLoader loader: FontLoader {{ source: {json.dumps(font.as_uri())} }}
    function has(name) {{ return GlyphMap.codepoints.hasOwnProperty(name); }}
    function glyph(name) {{
        const cp = GlyphMap.codepoints[name];
        return cp === undefined ? "" : String.fromCodePoint(cp);
    }}
}}
"""


def build(base: Path, *, experience: str = "everyday") -> Path:
    """Write the import tree under `base`; returns the import path."""
    services = base / "qs" / "services"
    config = base / "qs" / "config"
    utils = base / "qs" / "utils"
    kit = base / "Hornero" / "PluginKit"
    for d in (services, config, utils, kit):
        d.mkdir(parents=True, exist_ok=True)
    (services / "qmldir").write_text(
        "module qs.services\nsingleton Signal 1.0 Signal.qml\n"
        "singleton FocusMode 1.0 FocusMode.qml\nsingleton GameMode 1.0 GameMode.qml\n",
        encoding="utf-8")
    (services / "Signal.qml").write_text(_signal_stub(), encoding="utf-8")
    (services / "FocusMode.qml").write_text(
        "pragma Singleton\nimport QtQuick\nQtObject { property bool keyboard: true }\n", encoding="utf-8")
    (services / "GameMode.qml").write_text(
        "pragma Singleton\nimport QtQuick\nQtObject { property bool enabled: false }\n", encoding="utf-8")
    (config / "qmldir").write_text(
        "module qs.config\nsingleton Appearance 1.0 Appearance.qml\nsingleton Config 1.0 Config.qml\n",
        encoding="utf-8")
    (config / "Appearance.qml").write_text(_APPEARANCE, encoding="utf-8")
    (config / "Config.qml").write_text(_CONFIG, encoding="utf-8")
    (utils / "qmldir").write_text("module qs.utils\nsingleton Glyphs 1.0 Glyphs.qml\n", encoding="utf-8")
    (utils / "Glyphs.qml").write_text(_glyph_stub(), encoding="utf-8")
    shutil.copy(ROOT / "utils/GlyphMap.js", utils / "GlyphMap.js")
    for name in UI_FILES:
        shutil.copy(KIT / name, kit / name)
    bridge = kit / "ExperienceBridge.qml"
    # The bridge reads the shell's mode service; the harness pins a mode.
    bridge.write_text(
        "pragma Singleton\nimport QtQuick\nimport qs.services\nimport qs.config\nQtObject {\n"
        f"    property string mode: {json.dumps(experience)}\n"
        "    readonly property string density: mode === \"signal\" ? \"labels\" : \"values\"\n"
        "    readonly property bool glow: mode === \"signal\" && !Signal.light && Appearance.anim.effectiveLevel !== \"off\"\n"
        "    readonly property bool scanlines: mode === \"signal\" && !Signal.light\n"
        "    readonly property int telemetryIntervalMs: mode === \"signal\" ? 500 : 1000\n"
        "    readonly property bool telemetryPaused: false\n}\n", encoding="utf-8")
    qmldir = [line for line in (KIT / "qmldir").read_text(encoding="utf-8").splitlines()
              if not line.split()[-1:] or line.split()[-1] in UI_FILES or line.startswith("module")]
    (kit / "qmldir").write_text("\n".join(qmldir) + "\n", encoding="utf-8")
    return base


def run(test_file: Path, import_path: Path, timeout: int = 180) -> subprocess.CompletedProcess:
    runner = qmltestrunner()
    assert runner is not None
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    return subprocess.run(
        [str(runner), "-import", str(import_path), "-input", str(test_file)],
        capture_output=True, text=True, env=env, timeout=timeout)
