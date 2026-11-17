"""Signal instrument deck (RFC 0001 §5a/§5b, Visual Language §13).

services/deck.js is a pure module executed under node: the curated
catalogue, the per-screen layout solver, and the per-mode override rules
(persistence, reset). Static contracts pin how the QML hosts consume it.
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "deck.js"
EXPERIENCE = (ROOT / "services" / "Experience.qml").read_text()
CONFIG = (ROOT / "config" / "Config.qml").read_text()


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/deck.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def compose(area, hidden=(), reserved=(), saved=None, hints=None, ids=None):
    out = run_js(
        f"""
        const all = items({json.dumps(hints or {})});
        const want = {json.dumps(ids)};
        const list = want ? all.filter(i => want.includes(i.id)) : all;
        return compose({{area: {json.dumps(area)}, items: list, hidden: {json.dumps(list_(hidden))},
                        reserved: {json.dumps(list_(reserved))}, saved: {json.dumps(saved or {})}}});
        """
    )
    return out


def list_(v):
    return list(v)


def overlap(a, b):
    return a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"] and a["y"] < b["y"] + b["height"] and b["y"] < a["y"] + a["height"]


def assert_sane(res, area, reserved=()):
    ps = res["placements"]
    for p in ps:
        assert p["x"] >= 0 and p["y"] >= 0, p
        assert p["x"] + p["width"] <= area["width"], p
        assert p["y"] + p["height"] <= area["height"], p
        assert p["width"] > 0 and p["height"] > 0
        assert 0 <= p["fx"] <= 1 and 0 <= p["fy"] <= 1
        for r in reserved:
            assert not overlap(p, r), (p, r)
    for i, a in enumerate(ps):
        for b in ps[i + 1:]:
            if a["source"] == "deck" and b["source"] == "deck":
                assert not overlap(a, b), (a, b)


# Logical areas: physical resolution divided by the compositor scale,
# minus the bar edge and the shell margin the desktop layer already omits.
SCREENS = {
    "1080p@1": {"width": 1888, "height": 1000},
    "1440p@1.25": {"width": 2016, "height": 1120},
    "2160p@2": {"width": 1888, "height": 1000},
    "2160p@1.5": {"width": 2528, "height": 1400},
    "1366x768@1": {"width": 1334, "height": 690},
    "ultrawide": {"width": 3392, "height": 1300},
    "portrait": {"width": 1040, "height": 1800},
}


# --- catalogue ---------------------------------------------------------

def test_catalogue_is_the_curated_instrument_set():
    out = run_js("return ids();")
    assert out == [
        "hornero-system-insight", "hornero-network-scope", "hornero-audio-deck",
        "hornero-calendar", "hornero-agenda", "hornero-moon-phase",
    ]


def test_manifest_hints_override_catalogue_sizes_but_keep_minimums():
    out = run_js("""
        const it = items({"hornero-calendar": {width: 100, height: 100, minWidth: 200, minHeight: 300}});
        return it.find(i => i.id === "hornero-calendar");
    """)
    assert out["minWidth"] == 200 and out["minHeight"] == 300
    assert out["width"] == 200 and out["height"] == 300


# --- layout math -------------------------------------------------------

@pytest.mark.parametrize("name", list(SCREENS))
def test_default_layout_is_in_bounds_and_non_overlapping(name):
    area = SCREENS[name]
    res = compose(area)
    assert_sane(res, area)
    assert res["placements"], name


def test_large_screen_shows_the_whole_deck_on_both_flanks():
    area = SCREENS["2160p@1.5"]
    res = compose(area)
    assert res["dropped"] == []
    xs = {p["id"]: p["x"] for p in res["placements"]}
    assert len(xs) == 6
    sides = {"left" if x == 0 else "right" for x in xs.values()}
    assert sides == {"left", "right"}


def test_centre_stays_open_for_windows():
    for name, area in SCREENS.items():
        res = compose(area)
        left = max([p["x"] + p["width"] for p in res["placements"] if p["x"] == 0] or [0])
        right = min([p["x"] for p in res["placements"] if p["x"] != 0] or [area["width"]])
        if left and right < area["width"]:
            assert right - left >= min(480, int(area["width"] * 0.3)), name


def test_small_screen_degrades_by_priority_never_overflows():
    area = SCREENS["1366x768@1"]
    res = compose(area)
    assert_sane(res, area)
    shown = [p["id"] for p in res["placements"]]
    assert shown[0] == "hornero-system-insight"
    assert res["dropped"], "a 690 px tall area cannot hold six instruments"
    assert all(d["reason"] == "no-room" for d in res["dropped"])
    # Dropped widgets are the lowest-priority ones.
    order = run_js("return ids();")
    assert order.index(res["dropped"][0]["id"]) > order.index(shown[0])


def test_laptop_screen_gets_a_real_deck_not_one_card():
    res = compose(SCREENS["1366x768@1"])
    assert len(res["placements"]) >= 3
    assert_sane(res, SCREENS["1366x768@1"])


def test_tiny_area_places_nothing_and_does_not_throw():
    for area in ({"width": 0, "height": 0}, {"width": 300, "height": 200}):
        res = compose(area)
        assert res["placements"] == []
        assert len(res["dropped"]) == 6


def test_reserved_zone_is_never_covered():
    area = SCREENS["1080p@1"]
    clock = {"x": 1888 - 420, "y": 0, "width": 420, "height": 220}
    res = compose(area, reserved=[clock])
    assert_sane(res, area, reserved=[clock])
    assert any(p["id"] == "hornero-system-insight" for p in res["placements"])
    insight = next(p for p in res["placements"] if p["id"] == "hornero-system-insight")
    assert insight["y"] >= 220


def test_layout_is_deterministic():
    area = SCREENS["1440p@1.25"]
    assert compose(area) == compose(area)


def test_multi_monitor_screens_are_solved_independently():
    big, small = SCREENS["2160p@1.5"], SCREENS["1366x768@1"]
    a, b = compose(big), compose(small)
    assert len(a["placements"]) > len(b["placements"])
    # Fractions describe the same place on any resolution.
    for p in a["placements"]:
        free = big["width"] - p["width"]
        assert abs(p["x"] - round(p["fx"] * free)) <= 1


def test_hidden_widgets_are_skipped_and_reported():
    area = SCREENS["1080p@1"]
    res = compose(area, hidden=["hornero-system-insight"])
    assert all(p["id"] != "hornero-system-insight" for p in res["placements"])
    assert {"id": "hornero-system-insight", "reason": "hidden"} in res["dropped"]


def test_missing_extension_leaves_no_gap_reserved_for_it():
    area = SCREENS["1080p@1"]
    full = compose(area)
    partial = compose(area, ids=["hornero-network-scope", "hornero-audio-deck"])
    assert [p["id"] for p in partial["placements"]] == ["hornero-network-scope", "hornero-audio-deck"]
    assert_sane(partial, area)
    assert len(partial["placements"]) < len(full["placements"])


def test_user_geometry_wins_and_is_clamped():
    area = SCREENS["1080p@1"]
    saved = {"hornero-calendar": {"fx": 0.5, "fy": 0.5, "width": 300, "height": 400}}
    res = compose(area, saved=saved)
    cal = next(p for p in res["placements"] if p["id"] == "hornero-calendar")
    assert cal["source"] == "user"
    assert cal["width"] == 300 and cal["height"] == 400
    assert cal["x"] == round(0.5 * (area["width"] - 300))
    wild = {"hornero-calendar": {"fx": 9, "fy": -3, "width": 99999, "height": 5}}
    res = compose(area, saved=wild)
    cal = next(p for p in res["placements"] if p["id"] == "hornero-calendar")
    assert_sane({"placements": [cal]}, area)
    assert cal["height"] >= 340


# --- overrides: persistence and reset -----------------------------------

def test_overrides_are_per_mode_and_survive_a_round_trip():
    out = run_js("""
        let d = {};
        d = setHidden(d, "signal", "hornero-agenda", true).deck;
        d = setGeometry(d, "signal", "DP-1", "hornero-calendar", {fx: 0.25, fy: 0.5, width: 320, height: 420}).deck;
        d = setHidden(d, "studio", "hornero-calendar", true).deck;
        const stored = JSON.parse(JSON.stringify(d));
        return {
            signalHidden: hiddenFor(stored, "signal"),
            studioHidden: hiddenFor(stored, "studio"),
            everydayHidden: hiddenFor(stored, "everyday"),
            saved: savedFor(stored, "signal", "DP-1"),
            otherScreen: savedFor(stored, "signal", "HDMI-A-1"),
            custom: isCustomised(stored, "signal"),
            everydayCustom: isCustomised(stored, "everyday"),
        };
    """)
    assert out["signalHidden"] == ["hornero-agenda"]
    assert out["studioHidden"] == ["hornero-calendar"]
    assert out["everydayHidden"] == []
    assert out["saved"]["hornero-calendar"] == {"fx": 0.25, "fy": 0.5, "width": 320, "height": 420}
    assert out["otherScreen"] == {}
    assert out["custom"] is True and out["everydayCustom"] is False


def test_reset_restores_defaults_for_one_screen_or_the_whole_mode():
    out = run_js("""
        let d = {};
        d = setHidden(d, "signal", "hornero-agenda", true).deck;
        d = setGeometry(d, "signal", "DP-1", "hornero-calendar", {fx: 0.1, fy: 0.1}).deck;
        d = setGeometry(d, "signal", "DP-2", "hornero-calendar", {fx: 0.9, fy: 0.9}).deck;
        d = setHidden(d, "studio", "hornero-agenda", true).deck;
        const oneScreen = reset(d, "signal", "DP-1");
        const whole = reset(d, "signal", "");
        return {
            dp1: savedFor(oneScreen, "signal", "DP-1"),
            dp2: savedFor(oneScreen, "signal", "DP-2"),
            hiddenKept: hiddenFor(oneScreen, "signal"),
            wholeCustom: isCustomised(whole, "signal"),
            studioKept: hiddenFor(whole, "studio"),
        };
    """)
    assert out["dp1"] == {}
    assert "hornero-calendar" in out["dp2"]
    assert out["hiddenKept"] == ["hornero-agenda"]
    assert out["wholeCustom"] is False
    assert out["studioKept"] == ["hornero-agenda"]


def test_unhiding_removes_the_override_entirely():
    out = run_js("""
        let d = setHidden({}, "signal", "hornero-agenda", true).deck;
        d = setHidden(d, "signal", "hornero-agenda", false).deck;
        return {d: d, custom: isCustomised(d, "signal")};
    """)
    assert out["custom"] is False
    assert out["d"] == {"hidden": {}, "geometry": {}}


def test_sanitize_drops_garbage_and_rejects_bad_writes():
    out = run_js("""
        const dirty = {
            hidden: {signal: ["hornero-agenda", "../etc", 7, "hornero-agenda"], bogus: ["x"]},
            geometry: {signal: {"DP-1": {"hornero-calendar": {fx: 2, fy: "no", width: 10, height: 10}, "Bad Id": {fx: 0, fy: 0}}}},
        };
        return {
            clean: sanitizeDeck(dirty),
            badMode: setHidden({}, "nope", "hornero-agenda", true).ok,
            badId: setHidden({}, "signal", "../x", true).ok,
            badGeo: setGeometry({}, "signal", "DP-1", "hornero-calendar", {fx: "a"}).ok,
            notObject: sanitizeDeck("junk"),
        };
    """)
    assert out["clean"] == {"hidden": {"signal": ["hornero-agenda"]}, "geometry": {}}
    assert out["badMode"] is False and out["badId"] is False and out["badGeo"] is False
    assert out["notObject"] == {"hidden": {}, "geometry": {}}


def test_status_is_honest_about_every_widget():
    out = run_js("""
        const comp = compose({area: {width: 1888, height: 690}, items: items({}), hidden: ["hornero-agenda"]});
        return status(comp, {
            "hornero-system-insight": "ready",
            "hornero-network-scope": "ready",
            "hornero-audio-deck": "failed",
            "hornero-calendar": "untrusted",
            "hornero-agenda": "ready",
        }, ["hornero-agenda"]).map(s => [s.id, s.state]);
    """)
    states = dict(out)
    assert states["hornero-system-insight"] == "shown"
    assert states["hornero-audio-deck"] == "failed"
    assert states["hornero-calendar"] == "untrusted"
    assert states["hornero-agenda"] == "hidden"
    assert states["hornero-moon-phase"] == "not-installed"


# --- service contracts ---------------------------------------------------

def test_experience_persists_deck_overrides_through_config():
    assert "ExperienceConfig" in CONFIG
    assert "deck: experience.deck" in CONFIG
    for fn in ("setDeckHidden", "setDeckGeometry", "resetDeck"):
        assert f"function {fn}(" in EXPERIENCE
    # Resetting a mode's customisations restores its deck too.
    assert "Deck.reset(Config.experience.deck, id" in EXPERIENCE
    default = json.loads((ROOT / "config" / "shell.default.json").read_text())
    assert default["experience"]["deck"] == {}


# --- host wiring contracts ---------------------------------------------------

HOST = (ROOT / "modules" / "plugins" / "PluginDesktopWidgets.qml").read_text()
FRAME = (ROOT / "modules" / "plugins" / "DesktopWidgetFrame.qml").read_text()
BACKGROUND = (ROOT / "modules" / "background" / "Background.qml").read_text()
PLUGINS = (ROOT / "services" / "Plugins.qml").read_text()
PANE = (ROOT / "modules" / "controlcenter" / "experience" / "ExperiencePane.qml").read_text()


def test_user_geometry_is_placed_first_and_defaults_flow_around_it():
    area = SCREENS["1080p@1"]
    # The person parked the calendar where the system-insight rail would go.
    saved = {"hornero-calendar": {"fx": 1.0, "fy": 0.0, "width": 320, "height": 416}}
    res = compose(area, saved=saved)
    assert_sane(res, area)
    cal = next(p for p in res["placements"] if p["id"] == "hornero-calendar")
    insight = next(p for p in res["placements"] if p["id"] == "hornero-system-insight")
    assert cal["source"] == "user" and (cal["x"], cal["y"]) == (1888 - 320, 0)
    assert not overlap(cal, insight)


def test_deck_only_exists_in_the_instruments_profile():
    exp = (ROOT / "services" / "experience.js").read_text()
    # Only Signal ships `instruments`; every other mode hides or keeps the user's set.
    assert exp.count('"desktopWidgets": "instruments"') == 1
    assert 'Experience.instruments && Experience.desktopWidgetsVisible' in HOST
    assert 'Experience.desktopWidgets === "user" && Experience.desktopWidgetsVisible' in HOST


def test_gaming_and_focus_instantiate_nothing():
    # `none` profiles: neither the user set nor the deck is wanted, the
    # model is empty once the (<=90 ms at motion off) fade ends, and the
    # frame keeps its Loader inactive so no widget draws or holds a lease.
    assert "source: root.userSet ? Plugins.desktopPlugins() : []" in HOST
    assert "root.deckWanted ? Plugins.deckPlugins() : []" in HOST
    assert "root.deckWanted || deckLayer.opacity > 0 ? root._deckLast : []" in HOST
    assert 'readonly property bool suspended: Experience.desktopWidgets === "none"' in FRAME
    assert "active: !root.suspended" in FRAME
    exp = (ROOT / "services" / "experience.js").read_text()
    for mode in ("focus", "gaming"):
        block = exp[exp.index(f'"{mode}": _profile'):]
        block = block[: block.index("}),")]
        assert '"desktopWidgets": "none"' in block, mode
    assert "readonly property bool desktopWidgetsVisible: policy.desktopWidgetsVisible" in EXPERIENCE
    assert '!(gaming && fs)' in exp


def test_deck_enters_and_exits_with_the_shared_motion_primitives():
    assert "import qs.components.motion" in FRAME and "import qs.components.motion" in HOST
    assert "Choreography.rowDelay(root.channel - 1)" in FRAME
    assert "Choreography.scanTravel" in FRAME
    assert "FadeAnim" in HOST and "FadeAnim" in FRAME
    assert "leaving: !root.deckWanted" in HOST


def test_deck_geometry_never_touches_the_everyday_widget_layout():
    assert "Experience.setDeckGeometry(root.screenName, root.pluginId, geometry)" in FRAME
    assert "Experience.resetDeck(Experience.mode, root.screenName)" in HOST


def test_host_keeps_the_desktop_clock_clear():
    assert "reserved: clockLoader.item" in BACKGROUND
    assert "desktopWidgets.hasContent" in BACKGROUND


def test_missing_extensions_degrade_honestly():
    for state in ("not-installed", "untrusted", "failed", "safe-mode"):
        assert f'"{state}"' in PLUGINS
    assert "Plugins.deckAvailability()" in PANE
    assert "not installed" in PANE and "failed to load" in PANE


def test_deck_never_writes_extension_lifecycle_state():
    body = PLUGINS[PLUGINS.index("function deckEligible"): PLUGINS.index("function setDesktopEditing")]
    assert "horneroctl" not in body and "Process" not in body


def test_glow_stays_inside_amendment_2_limits():
    # The deck never draws glow itself: PluginKit instruments lease it from
    # GlowBudget (3 items, 4 px, 40 %), and only when Experience.glow holds.
    for src in (HOST, FRAME):
        assert "MultiEffect" not in src and "palette.glow" not in src and "DropShadow" not in src
    kit = (ROOT / "plugin" / "qml" / "Hornero" / "PluginKit" / "GlowBudget.qml").read_text()
    assert "readonly property int limit: 3" in kit
    theme = (ROOT / "plugin" / "qml" / "Hornero" / "PluginKit" / "Theme.qml").read_text()
    assert "glowBlur: 4" in theme and "glowAlpha: 0.4" in theme


def test_idle_cpu_script_is_guarded_and_documented():
    import os
    script = ROOT / "scripts" / "perf-signal-deck.sh"
    assert os.access(script, os.X_OK)
    proc = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    env = {k: v for k, v in os.environ.items() if k != "HORNERO_DISPOSABLE_SESSION"}
    refused = subprocess.run([str(script)], capture_output=True, text=True, env=env)
    assert refused.returncode == 3 and "HORNERO_DISPOSABLE_SESSION" in refused.stderr
    body = script.read_text()
    assert 'qs ipc call experience set' in body and "restore" in body
    doc = (ROOT / "docs" / "EXPERIENCE.md").read_text()
    assert "scripts/perf-signal-deck.sh" in doc and "vm.lock" in doc
    assert "EXPERIENCE.md" in (ROOT / "docs" / "PLUGINS.md").read_text()


def test_deck_ipc_is_documented_and_validated():
    assert "function deck(mode: string)" in EXPERIENCE
    assert "function resetDeck(mode: string)" in EXPERIENCE
    ipc = (ROOT / "docs" / "IPC.md").read_text()
    for fn in ("experience deck", "experience setDeckHidden", "experience resetDeck"):
        assert f"`{fn}" in ipc
