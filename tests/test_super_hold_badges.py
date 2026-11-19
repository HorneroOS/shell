"""SUPER-hold key badges (shell#701, COMPETITIVE gap #5 deferred from
#698): the hold state machine and badge model in services/keybinds.js
run under node; the service shortcuts, workspace-cell hook, settings
and Control Center controls are pinned by source contracts."""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "keybinds.js"
SERVICE = ROOT / "services" / "Keybinds.qml"
CELL = ROOT / "modules" / "bar" / "components" / "workspaces" / "Workspace.qml"
PANE = ROOT / "modules" / "controlcenter" / "keybinds" / "KeybindsPane.qml"

# Shape of `horneroctl hardware keyboard rebind list --json` data.entries,
# including the non-consuming detection binds HorneroOS/config registers.
ENTRIES = [
    {"combo": "SUPER + Return", "original": "SUPER + Return", "category": "Essential Applications",
     "action": 'hl.dsp.exec_cmd("exo-open --launch TerminalEmulator")', "submap": "", "source": "factory",
     "dispatcher": "exec_cmd", "remapped": False, "mouse": False},
    {"combo": "SUPER + 1", "original": "SUPER + 1", "category": "Workspace Management",
     "action": 'hl.dsp.focus({ workspace = "1" })', "submap": "", "source": "factory",
     "dispatcher": "focus", "remapped": False, "mouse": False},
    {"combo": "SUPER + 0", "original": "SUPER + 0", "category": "Workspace Management",
     "action": 'hl.dsp.focus({ workspace = "10" })', "submap": "", "source": "factory",
     "dispatcher": "focus", "remapped": False, "mouse": False},
    {"combo": "SUPER + SHIFT + 1", "original": "SUPER + SHIFT + 1", "category": "Workspace Management",
     "action": 'hl.dsp.window.move({ workspace = "1" })', "submap": "", "source": "factory",
     "dispatcher": "move", "remapped": False, "mouse": False},
    {"combo": "SUPER + mouse:272", "original": "SUPER + mouse:272", "category": "Mouse Bindings",
     "action": 'hl.dsp.window.drag()', "submap": "", "source": "factory", "dispatcher": "drag",
     "remapped": False, "mouse": True},
    {"combo": "Super_L", "original": "", "category": "Other",
     "action": 'hl.dsp.global("hornero:superHoldArm")', "submap": "", "source": "live",
     "dispatcher": "global", "remapped": False, "mouse": False},
    {"combo": "SUPER + Super_L", "original": "", "category": "Other",
     "action": 'hl.dsp.global("hornero:superHoldRelease")', "submap": "", "source": "live",
     "dispatcher": "global", "remapped": False, "mouse": False},
    {"combo": "SUPER + Return", "original": "", "category": "Other",
     "action": "global, hornero:superHoldInterrupt", "submap": "", "source": "live",
     "dispatcher": "global", "remapped": False, "mouse": False},
]


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/keybinds.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    prelude = "var RAW = " + json.dumps(json.dumps(ENTRIES)) + "; var E = normalise(RAW);\n"
    proc = subprocess.run([node, "-e", src + "\n" + prelude + "console.log(JSON.stringify((() => {" + expr + "})()));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_detection_binds_are_hidden_from_the_bind_list():
    rows = run_js("return E.map(r => r.combo + '|' + r.shared);")
    # The interrupt bind rides on SUPER + Return; hiding it keeps the
    # real bind single (no false "shared x2") and the list clean.
    assert rows.count("SUPER + Return|1") == 1
    assert not any("Super_L" in r for r in rows)


def test_badges_show_only_after_the_configured_hold():
    out = run_js(
        "var o = {enabled: true, holdMs: 600}; var s = holdStep(holdState(), 'press', o, 1000);"
        "var early = holdStep(s, 'tick', o, 1599).visible;"
        "var at = holdStep(s, 'tick', o, 1600);"
        "return [early, at.visible, at.phase];")
    assert out == [False, True, "shown"]


def test_custom_hold_threshold_is_honoured():
    out = run_js(
        "var o = {enabled: true, holdMs: 250}; var s = holdStep(holdState(), 'press', o, 0);"
        "return [holdStep(s, 'tick', o, 249).visible, holdStep(s, 'tick', o, 250).visible];")
    assert out == [False, True]


def test_opt_out_never_shows_badges():
    out = run_js(
        "var o = {enabled: false, holdMs: 600}; var s = holdStep(holdState(), 'press', o, 0);"
        "return [s.phase, holdStep(s, 'tick', o, 5000).visible];")
    assert out == ["idle", False]
    # Turning it off mid-hold hides badges on the next tick.
    out = run_js(
        "var on = {enabled: true, holdMs: 600}; var s = holdStep(holdState(), 'press', on, 0);"
        "s = holdStep(s, 'tick', on, 600); return holdStep(s, 'tick', {enabled: false, holdMs: 600}, 650).visible;")
    assert out is False


def test_a_combo_hides_badges_and_cancels_the_hold():
    out = run_js(
        "var o = {enabled: true, holdMs: 600}; var s = holdStep(holdState(), 'press', o, 0);"
        "s = holdStep(s, 'interrupt', o, 300);"
        "var afterCombo = holdStep(s, 'tick', o, 1000).visible;"
        "var s2 = holdStep(holdState(), 'press', o, 0); s2 = holdStep(s2, 'tick', o, 600);"
        "var shownThenCombo = holdStep(s2, 'interrupt', o, 700).visible;"
        "return [afterCombo, shownThenCombo];")
    assert out == [False, False]


def test_release_hides_badges_and_a_missed_release_cannot_strand_them():
    out = run_js(
        "var o = {enabled: true, holdMs: 600}; var s = holdStep(holdState(), 'press', o, 0);"
        "s = holdStep(s, 'tick', o, 600);"
        "var onRelease = holdStep(s, 'release', o, 700);"
        "var stranded = holdStep(s, 'tick', o, 600 + BADGE_MAX_SHOWN_MS + 600).visible;"
        "return [onRelease.visible, onRelease.phase, stranded];")
    assert out == [False, "idle", False]


def test_badge_settings_clamp_to_the_schema_range():
    assert run_js("return badgeSettings({enabled: 'yes', holdMs: 5});") == {"enabled": True, "holdMs": 200}
    assert run_js("return badgeSettings({enabled: false, holdMs: 99999});") == {"enabled": False, "holdMs": 3000}
    assert run_js("return badgeSettings(null);") == {"enabled": True, "holdMs": 600}
    assert run_js("return badgeSettings({holdMs: 'soon'}).holdMs;") == 600


def test_super_badges_are_bare_super_binds_only():
    badges = run_js("return superBadges(E).map(b => b.key);")
    assert badges == ["Return", "1", "0"]  # no SHIFT variant, no mouse, no plumbing


def test_workspace_badges_follow_the_live_binds():
    assert run_js("return workspaceBadges(E);") == {"1": "1", "10": "0"}
    moved = run_js(
        "var X = normalise(JSON.stringify(JSON.parse(RAW).map(e => e.combo === 'SUPER + 0' ? {...e, combo: 'SUPER + F10'} : e)));"
        "return workspaceBadges(X);")
    assert moved == {"1": "1", "10": "F10"}


def test_badge_defaults_agree_with_factory_qml_and_ranges():
    factory = json.loads((ROOT / "config" / "shell.default.json").read_text())["keybinds"]["superHold"]
    assert run_js("return BADGE_DEFAULTS;") == factory
    qml = (ROOT / "config" / "KeybindsConfig.qml").read_text()
    assert "property bool enabled: true" in qml and "property int holdMs: 600" in qml
    ranges = json.loads((ROOT / "config" / "ranges.json").read_text())["ranges"]
    assert ranges["keybinds.superHold.holdMs"] == {"min": 200, "max": 3000, "step": 50, "default": 600}
    assert run_js("return [BADGE_HOLD_MIN, BADGE_HOLD_MAX];") == [200, 3000]
    serializer = (ROOT / "config" / "Config.qml").read_text()
    assert "enabled: keybinds.superHold.enabled" in serializer
    assert "holdMs: keybinds.superHold.holdMs" in serializer


def test_service_contract():
    text = SERVICE.read_text()
    for name in ("superHoldArm", "superHoldRelease", "superHoldInterrupt"):
        assert f'name: "{name}"' in text, name
    assert 'holdEvent("press")' in text and 'holdEvent("release")' in text and 'holdEvent("interrupt")' in text
    assert 'holdEvent("tick")' in text
    # Badges follow the gaming focus contract (never over fullscreen).
    assert "hasFullscreenOnFocusedOutput()" in text
    assert "Model.holdStep(" in text and "Model.workspaceBadges(" in text


def test_workspace_cell_badge_hook():
    text = CELL.read_text()
    assert "Keycap {" in text
    assert "Keybinds.badgesVisible" in text
    assert "Keybinds.workspaceBadge(root.ws)" in text


def test_pane_exposes_badge_controls_with_reset():
    text = PANE.read_text()
    assert 'root.setSuperHold("enabled"' in text
    assert 'key: "holdMs"' in text and "defaultValue: 600" in text
    assert "Reset badge settings" in text and 'Undo.offerValues("keybinds-superhold"' in text


def test_badge_strings_are_translated():
    ts = (ROOT / "i18n" / "hornero_es_AR.ts").read_text()
    for source in ("SUPER-hold key badges", "Show key badges when holding SUPER",
                   "Hold SUPER for", "Reset badge settings"):
        assert f"<source>{source}</source>" in ts, source
    # No new string ships untranslated.
    block = re.findall(r"<source>(?:[^<]*SUPER[^<]*)</source>\s*<translation([^>]*)>", ts)
    assert all('type="unfinished"' not in attrs for attrs in block)
