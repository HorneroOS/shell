"""Plugin bar items never overlap core segments and respect an overflow budget (shell#531).

The pure model (modules/plugins/baroverflow.js) runs under node. The runtime
test renders the real Quick actions island and Extensions island over the real
Plugins service, fed by generated fixture plugins whose indicators are wider
than their island's budget, at 1280, 1366 and 1920 px, and fails on any
overlap, any indicator past the item width clamp, or an indicator that
vanishes instead of moving to the Extensions island. It is skipped, never
faked, without quickshell.
"""
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs

JS = ROOT / "modules" / "plugins" / "baroverflow.js"
WIDGETS = (ROOT / "modules" / "plugins" / "PluginBarWidgets.qml").read_text()


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute baroverflow.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def items(*widths, priority=None):
    return json.dumps([{"id": f"p{i}", "width": w, "priority": (priority or {}).get(i)} for i, w in enumerate(widths)])


# --- Model -------------------------------------------------------------------

def test_everything_that_fits_stays():
    out = run_js(f"return plan({items(60, 60, 60)}, 300, 6, 160)")
    assert out == {"keep": ["p0", "p1", "p2"], "overflow": []}


def test_the_item_that_does_not_fit_and_everything_after_it_overflow():
    out = run_js(f"return plan({items(100, 100, 100, 20)}, 220, 6, 160)")
    assert out["keep"] == ["p0", "p1"]
    assert out["overflow"] == ["p2", "p3"], "a small low-priority item never jumps the queue"


def test_priority_beats_declaration_order():
    out = run_js(f"return plan({items(100, 100, 100, priority={2: 90})}, 210, 6, 160)")
    assert out["keep"] == ["p0", "p2"] and out["overflow"] == ["p1"]


def test_items_are_clamped_to_the_item_width_before_planning():
    out = run_js(f"return plan({items(900, 900)}, 330, 6, 160)")
    assert out == {"keep": ["p0", "p1"], "overflow": []}


def test_empty_and_unmeasured_items_take_no_room():
    out = run_js(f"return plan({items(0, 120, 0)}, 130, 6, 160)")
    assert out == {"keep": ["p0", "p1", "p2"], "overflow": []}


def test_no_budget_means_unlimited():
    out = run_js(f"return plan({items(500, 500)}, 0, 6, 160)")
    assert out["overflow"] == []


def test_budget_is_a_share_of_the_bar_main_axis():
    assert run_js("return budgetFor(1920, 18)") == 345
    assert run_js("return budgetFor(0, 18)") == 0
    assert run_js("return budgetFor(1920, 500)") == 1920


@pytest.mark.parametrize("raw,expected", [(None, 50), ("x", 50), (3.5, 50), (-4, 0), (400, 100), (70, 70)])
def test_priority_is_normalised(raw, expected):
    assert run_js(f"return priorityOf({json.dumps(raw)})") == expected


# --- Contracts ---------------------------------------------------------------

def test_hosts_overflow_into_the_extensions_island_only():
    island = (ROOT / "modules/bar/components/ExtensionsIsland.qml").read_text()
    assert "Plugins.setOverflowSink" in island and "acceptOverflow: true" in island
    assert "Config.bar.extensions.islandBudget / 100" in island
    assert 'root.section !== "end" && Plugins.hasOverflowSink(root.barKey)' in WIDGETS
    for rel in ("QuickActions", "Clock", "StatusIcons"):
        src = (ROOT / f"modules/bar/components/{rel}.qml").read_text()
        assert "PluginBarWidgets {" in src


def test_items_are_clamped_and_data_less_plugins_leave_the_bar():
    assert "Config.bar.extensions.itemMaxWidth" in WIDGETS
    assert 'width: root.vertical ? pluginLoader.natWidth : Math.min(pluginLoader.natWidth, root.availableMain)' in WIDGETS
    assert '"available" in pluginLoader.item' in WIDGETS


def test_every_limit_is_a_persisted_user_setting_with_a_reset():
    cfg = json.loads((ROOT / "config/shell.default.json").read_text())["bar"]["extensions"]
    assert (cfg["itemMaxWidth"], cfg["sectionBudget"], cfg["islandBudget"]) == (160, 18, 40)
    pane = (ROOT / "modules/controlcenter/taskbar/TaskbarPane.qml").read_text()
    for key in ("itemMaxWidth", "sectionBudget", "islandBudget"):
        assert f'key: "{key}"' in pane
        assert f"{key}: bar.extensions.{key}" in (ROOT / "config/Config.qml").read_text()
    ranges = json.loads((ROOT / "config/ranges.json").read_text())["ranges"]
    assert ranges["bar.extensions.itemMaxWidth"]["default"] == 160


# --- Runtime, offscreen ------------------------------------------------------

FIXTURE_COUNT = 14


def _plugin(root: Path, n: int, shrink_at_ms: int = 0) -> str:
    pid = f"ov-fixture-{n:02d}"
    d = root / pid
    d.mkdir()
    (d / "manifest.json").write_text(json.dumps({
        "schemaVersion": 3, "id": pid, "name": pid, "version": "1.0.0",
        "description": "Wide bar indicator for the overflow test.",
        "entrypoint": "Main.qml", "placement": "bar", "files": ["Main.qml"],
        "surfaces": {"bar": {"entrypoint": "Main.qml", "section": "actions"}},
    }))
    # shrink_at_ms: wall-clock epoch (ms) after which every instance of the
    # indicator, wherever it is hosted, reports a narrow width. Shared by all
    # instances so moving a plugin (a new instance) does not reset it.
    (d / "Main.qml").write_text(
        "import QtQuick\n"
        "Item {\n"
        "    id: ind\n"
        f"    readonly property real shrinkAt: {shrink_at_ms}\n"
        "    property bool narrow: shrinkAt > 0 && Date.now() >= shrinkAt\n"
        "    Timer {\n"
        "        interval: 100\n"
        "        repeat: true\n"
        "        running: ind.shrinkAt > 0 && !ind.narrow\n"
        "        onTriggered: ind.narrow = Date.now() >= ind.shrinkAt\n"
        "    }\n"
        "    implicitWidth: narrow ? 30 : 260\n"
        "    implicitHeight: 16\n"
        "    Text {\n"
        "        anchors.fill: parent\n"
        f'        text: "Wide indicator label number {n}"\n'
        "        color: palette.windowText\n"
        "        elide: Text.ElideRight\n"
        "        font.pixelSize: 12\n"
        "    }\n"
        "}\n")
    return pid


HIDDEN = "ov-fixture-13"


def render(tmp_path: Path, width: int, count: int = FIXTURE_COUNT, shrink_after_s: float = 0, report_ms: int = 9000) -> dict:
    root = tmp_path / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests" / "qml" / "bar_overflow" / "harness.qml", root / "shell.qml")

    xdg = tmp_path / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero/plugins", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    shrink_at = int((time.time() + shrink_after_s) * 1000) if shrink_after_s > 0 else 0
    ids = [_plugin(xdg / "data" / "hornero" / "plugins", n, shrink_at) for n in range(count)]
    cfg = json.loads((ROOT / "config" / "shell.default.json").read_text())
    # Hidden on the Extensions island: must not hide it once it overflows
    # there from the Quick actions island (it always does: 14 never fit).
    cfg["bar"]["extensions"]["hiddenIcons"] = [HIDDEN]
    (xdg / "config" / "hornero" / "shell.json").write_text(json.dumps(cfg))
    bindir = tmp_path / "bin"
    bindir.mkdir()
    listing = json.dumps([{"id": i, "name": i, "version": "1.0.0", "installed": True, "enabled": True, "trust": "official"} for i in ids])
    payload = json.dumps({"command": "plugin list", "ok": True, "message": f"{len(ids)} plugins", "data": {"plugins": listing}})
    script = bindir / "horneroctl"
    script.write_text("#!/bin/sh\n"
                      'if [ "$1 $2" = "plugin list" ]; then\n'
                      f"cat <<'JSON'\n{payload}\nJSON\n"
                      "exit 0\nfi\nexit 0\n")
    script.chmod(0o755)

    env = {
        "PATH": f"{bindir}:{os.environ['PATH']}",
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "OV_W": str(width), "OV_REPORT_MS": str(report_ms),
    }
    if os.environ.get("OV_OUT"):
        env["OV_OUT"] = os.environ["OV_OUT"]
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=120, env=env, cwd=tmp_path)
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
    lines = [ln for ln in log.splitlines() if "POVF " in ln]
    assert lines, f"harness never reported:\n{log[-2500:]}"
    return json.loads(lines[-1].split("POVF ", 1)[1])


@requires_qs
@pytest.mark.parametrize("width", [1280, 1366, 1920])
def test_no_indicator_overlaps_and_the_rest_move_to_the_extensions_island(tmp_path: Path, width: int):
    report = render(tmp_path, width)
    assert all(s.endswith(":loaded") for s in report["states"]) and len(report["states"]) == FIXTURE_COUNT, (report["states"], report["details"])
    rects = report["rects"]
    assert rects, "no plugin indicator was rendered"

    # Nothing overlaps (a one pixel tolerance for rounding) and nothing is
    # wider than the item clamp.
    for i, a in enumerate(rects):
        assert a["w"] <= 160 + 0.5, a
        for b in rects[i + 1:]:
            ox = min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"])
            oy = min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"])
            assert not (ox > 1 and oy > 1), (a, b)

    # The Quick actions island keeps its plugin indicators inside its budget
    # (18 % of the bar)...
    in_actions = [r for r in rects if r["host"] == "actions"]
    budget = width * 0.18
    assert in_actions and sum(r["w"] for r in in_actions) <= budget + 1, in_actions
    # ...and nothing is lost: each fixture is either kept there or handed to
    # the Extensions island, which really instantiated it.
    overflowed = {i for ids in report["overflow"].values() for i in ids}
    assert overflowed, "14 wide indicators must not all fit one island"
    kept = {r["id"] for r in in_actions}
    in_island = {r["id"] for r in rects if r["host"] == "island"}
    assert kept | overflowed == {f"ov-fixture-{n:02d}" for n in range(FIXTURE_COUNT)}
    assert not kept & overflowed
    assert overflowed == in_island, (overflowed, in_island)
    assert HIDDEN in in_island, "bar.extensions.hiddenIcons must not hide an overflowed indicator"


@requires_qs
def test_an_overflowed_indicator_that_shrinks_comes_back(tmp_path: Path):
    """Overflow is not sticky: the island reports the new width of an
    overflowed plugin and the source island re-plans with it."""
    width = 1280
    report = render(tmp_path, width, shrink_after_s=4, report_ms=11000)
    rects = report["rects"]
    in_actions = [r for r in rects if r["host"] == "actions"]
    budget = int(width * 0.18)
    assert all(r["w"] <= 31 for r in rects), rects
    used = sum(r["w"] for r in in_actions) + 6 * max(0, len(in_actions) - 1)
    assert used <= budget, in_actions
    # Tight plan: the next 30 px indicator would not have fit (with the
    # 16 px return slack an away indicator needs to come back).
    assert used + 6 + 30 + 16 > budget, (used, budget, in_actions)
    # With stale (pre-shrink) widths only one or two would have stayed.
    assert len(in_actions) >= 4, in_actions
    bar = next(iter(report["widths"]))
    assert bar.endswith("|top"), report["widths"]
    assert set(report["overflow"]) == {bar + "|actions"}


# --- Model: stability and per-bar keys ---------------------------------------

def test_an_overflowed_item_needs_slack_to_come_back():
    its = json.dumps([{"id": "a", "width": 100}, {"id": "b", "width": 100, "overflowed": True}])
    assert run_js(f"return plan({its}, 210, 6, 160, 16)")["overflow"] == ["b"]
    assert run_js(f"return plan({its}, 222, 6, 160, 16)")["overflow"] == []
    kept = json.dumps([{"id": "a", "width": 100}, {"id": "b", "width": 100}])
    assert run_js(f"return plan({kept}, 210, 6, 160, 16)")["overflow"] == [], "slack never evicts a kept item"


def test_overflow_is_keyed_per_bar_not_per_screen():
    plugins = (ROOT / "services/Plugins.qml").read_text()
    assert "const key = `${bar}|${section}`;" in plugins
    assert "readonly property string barKey: `${root.screenName}|${root.barEdge}`" in WIDGETS
    island = (ROOT / "modules/bar/components/ExtensionsIsland.qml").read_text()
    assert "|${root.barEdge}`" in island and island.count("barEdge: root.barEdge") == 2
    bar = (ROOT / "modules/bar/Bar.qml").read_text()
    assert bar.count("barEdge: root.edge") == 4
    for rel in ("QuickActions", "Clock", "StatusIcons"):
        assert "barEdge: root.barEdge" in (ROOT / f"modules/bar/components/{rel}.qml").read_text()


def test_hidden_icons_never_hide_overflow_guests():
    assert "(root.acceptOverflow && Plugins.isBarOverflowed(root.barKey, p.id)) || (!root.hiddenIds.includes(p.id)" in WIDGETS


def test_only_overflow_guests_get_the_extra_margin():
    assert "Layout.leftMargin: pluginLoader.guest && !root.vertical ? root.itemGap : 0" in WIDGETS
    assert "Layout.topMargin: pluginLoader.guest && root.vertical ? root.itemGap : 0" in WIDGETS


def test_overflowed_items_are_planned_with_the_island_width():
    assert "Plugins.barItemWidth(root.barKey, id)" in WIDGETS
    assert "Plugins.setBarItemWidth(root.barKey, pluginLoader.modelData.id, pluginLoader.measuredMain)" in WIDGETS
    assert "function onBarItemWidthsChanged()" in WIDGETS
    assert "Math.min(reported >= 0 ? reported : d.measuredMain, root.availableMain)" in WIDGETS


def test_widest_indicator_slider_shows_pixels():
    pane = (ROOT / "modules/controlcenter/taskbar/TaskbarPane.qml").read_text()
    block = pane[pane.index('key: "itemMaxWidth"'):][:400]
    assert 'suffix: "px"' in block


def test_plugin_bar_items_keep_real_type_scale_and_cross_axis_bounds():
    assert "property real iconSize: 0" in WIDGETS
    assert "property real textSize: 0" in WIDGETS
    assert "property real microSize: 0" in WIDGETS
    assert "readonly property real hostIconSize: root.iconSize" in WIDGETS
    assert "readonly property real hostTextSize: root.textSize" in WIDGETS
    assert "readonly property real hostMicroSize:" in WIDGETS
    assert "Math.min(pluginLoader.natHeight, root.availableCross)" in WIDGETS
    assert "Layout.preferredWidth:" in WIDGETS and "Layout.preferredHeight:" in WIDGETS

    ui_text = (ROOT / "plugin/qml/Hornero/PluginKit/UiText.qml").read_text()
    assert '"hostTextSize" in p' in ui_text
    assert "hostStyle.hostMicroSize" in ui_text
    assert "root.islandStyled ? Text.AlignVCenter : Text.AlignTop" in ui_text

    ui_button = (ROOT / "plugin/qml/Hornero/PluginKit/UiButton.qml").read_text()
    assert "hostStyle.hostTextFamily" in ui_button
    assert "hostStyle.hostAvailableHeight" in ui_button or "hostContext.hostAvailableHeight" in ui_button


def test_extensions_island_caps_width_against_start_group():
    bar = (ROOT / "modules/bar/Bar.qml").read_text()
    assert "maxExtensionRoom" in bar
    assert "maxMain: group.maxExtensionRoom" in bar
    assert "Math.max(s.mainPos + s.mainLen + root.groupSpacing, total - mainLen - m)" in bar
    island = (ROOT / "modules/bar/components/ExtensionsIsland.qml").read_text()
    assert "property real maxMain: -1" in island
    assert "root.maxMain >= 0 ? Math.min(configuredLimit, root.maxMain)" in island
    assert "root.maxMain >= 0 ? Math.min(rawWidth, root.maxMain)" in island
