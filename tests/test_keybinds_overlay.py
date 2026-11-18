"""Keybinding overlay (COMPETITIVE gap #5): services/keybinds.js runs
under node; the overlay surface, IPC target, settings and Control Center
controls are pinned by source contracts."""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "keybinds.js"
OVERLAY = ROOT / "modules" / "keybinds" / "KeybindsOverlay.qml"
SHEET = ROOT / "modules" / "keybinds" / "KeybindsSheet.qml"
PANE = ROOT / "modules" / "controlcenter" / "keybinds" / "KeybindsPane.qml"
GLYPHS = ROOT / "assets" / "fonts" / "hornero-glyphs.names"

# Shape of `horneroctl hardware keyboard rebind list --json` data.entries.
ENTRIES = [
    {"combo": "SUPER + Return", "original": "SUPER + Return", "category": "Essential Applications",
     "action": 'hl.dsp.exec_cmd("exo-open --launch TerminalEmulator")', "submap": "", "source": "factory",
     "dispatcher": "exec_cmd", "remapped": False, "mouse": False},
    {"combo": "SUPER + X", "original": "SUPER + slash", "category": "Essential Applications",
     "action": 'hl.dsp.exec_cmd("horneroctl hardware keyboard keys")', "submap": "", "source": "factory",
     "dispatcher": "exec_cmd", "remapped": True, "mouse": False},
    {"combo": "SUPER + K", "original": "SUPER + K", "category": "Focus Movement (Vim-like)",
     "action": 'hl.dsp.focus({ direction = "up" })', "submap": "", "source": "factory",
     "dispatcher": "focus", "remapped": False, "mouse": False},
    {"combo": "SUPER + SHIFT + F", "original": "SUPER + SHIFT + F", "category": "Window Management",
     "action": "function() helpers.smart_float() end", "submap": "", "source": "factory",
     "dispatcher": "lua function", "remapped": False, "mouse": False},
    {"combo": "escape", "original": "escape", "category": "Window Resizing", "action": 'hl.dsp.submap("reset")',
     "submap": "resize", "source": "factory", "dispatcher": "submap", "remapped": False, "mouse": False},
    {"combo": "SUPER + mouse:272", "original": "SUPER + mouse:272", "category": "Mouse Bindings",
     "action": 'hl.dsp.window.drag()', "submap": "", "source": "factory", "dispatcher": "drag",
     "remapped": False, "mouse": True},
    {"combo": "escape", "original": "", "category": "Submap: hornero_capture", "action": "submap",
     "submap": "hornero_capture", "source": "live", "dispatcher": "submap", "remapped": False, "mouse": False},
    {"combo": "SUPER + Tab", "original": "", "category": "Other", "action": "lua function", "submap": "",
     "source": "live", "dispatcher": "lua function", "remapped": False, "mouse": False},
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


def test_canonical_matches_loader_and_cli():
    assert run_js('return canonical("control + super + t") === canonical("SUPER + CTRL + T");')
    assert run_js('return canonical("SUPER + Return");') == "SUPER + return"
    assert run_js('return canonical("$mainMod + slash") === canonical("SUPER+slash");')


def test_normalise_hides_internal_submaps_and_labels_actions():
    rows = run_js("return E;")
    assert all(r["submap"] != "hornero_capture" for r in rows)
    by = {r["combo"]: r for r in rows if r["submap"] == ""}
    assert by["SUPER + Return"]["label"] == "exo-open --launch TerminalEmulator"
    assert by["SUPER + SHIFT + F"]["label"] == "smart_float"
    assert by["SUPER + K"]["label"].startswith("focus(")
    assert by["SUPER + X"]["remapped"] and by["SUPER + X"]["keys"] == ["SUPER", "X"]


def test_every_category_glyph_exists_in_the_hornero_glyph_font():
    names = {ln.strip() for ln in GLYPHS.read_text().splitlines() if ln and not ln.startswith("#")}
    glyphs = run_js("var out = []; for (var k in CATEGORIES) out.push(CATEGORIES[k].glyph); "
                    "out.push(categoryInfo('Submap: x').glyph, categoryInfo('Unknown').glyph); return out;")
    missing = [g for g in glyphs if g not in names]
    assert not missing, missing


def test_grouping_orders_by_purpose_and_filters():
    groups = run_js("return grouped(E, '', {}).map(g => [g.name, g.glyph, g.rows.length]);")
    names = [g[0] for g in groups]
    assert names[0] == "Essential Applications"
    assert names.index("Focus Movement (Vim-like)") < names.index("Mouse Bindings") < names.index("Other")
    assert ["Essential Applications", "apps", 2] in groups
    no_sub = run_js("return flatten(grouped(E, '', {showSubmaps: false, showMouse: false})).map(r => r.combo);")
    assert "escape" not in no_sub and "SUPER + mouse:272" not in no_sub


def test_search_matches_english_and_spanish():
    assert run_js("return flatten(grouped(E, 'terminal', {})).map(r => r.combo);") == ["SUPER + Return"]
    # Spanish category label ("Mover el foco") and multi-token queries.
    assert run_js("return flatten(grouped(E, 'foco', {})).map(r => r.combo);") == ["SUPER + K"]
    assert run_js("return flatten(grouped(E, 'super shift', {})).map(r => r.combo);") == ["SUPER + SHIFT + F"]
    assert run_js("return flatten(grouped(E, 'zzz-nothing', {})).length;") == 0


def test_conflicts_are_detected_before_saving():
    hit = run_js("var c = conflictFor(E, 'super + k', 'SUPER + Return'); return c && c.combo;")
    assert hit == "SUPER + K"
    assert run_js("return conflictFor(E, 'SUPER + K', 'SUPER + K');") is None
    assert run_js("return conflictFor(E, 'SUPER + F13', 'SUPER + K');") is None
    # Submap binds never conflict with global combos.
    assert run_js("return conflictFor(E, 'escape', 'SUPER + K');") is None


def test_shared_combos_are_flagged():
    rows = run_js("var X = normalise(JSON.stringify(JSON.parse(RAW).concat([{combo: 'SUPER + K', category: 'Personal', "
                  "action: 'x', submap: '', source: 'personal'}]))); return X.filter(r => r.combo === 'SUPER + K').map(r => r.shared);")
    assert rows == [2, 2]
    assert run_js("return E.filter(r => r.combo === 'SUPER + Return')[0].shared;") == 1


def test_summon_combo_follows_the_rebind():
    assert run_js("return summonCombo(E);") == "SUPER + X"


def test_key_capture_builds_hyprland_combos():
    meta, shift, ctrl, alt = 0x10000000, 0x02000000, 0x04000000, 0x08000000
    cases = {
        (0x4B, meta): "SUPER + K",
        (0x2F, meta): "SUPER + slash",
        (0x3F, meta | shift): "SUPER + SHIFT + question",
        (0x01000004, ctrl | alt): "CTRL + ALT + Return",
        (0x01000030 + 12, meta): "SUPER + F13",
        (0x01000012, meta | shift): "SUPER + SHIFT + left",
        (0x01000022, meta): "",  # Meta alone: keep listening
        (0x01000053, meta): "",  # Super_L alone
    }
    for (key, mods), want in cases.items():
        assert run_js(f"return comboFromKey({key}, {mods});") == want, (hex(key), want)


def test_run_expression_is_a_quoted_registry_call():
    assert run_js("return runExpression({combo: 'SUPER + \"x'});") == 'hornero_keybinds.run("SUPER + \\"x")'
    assert run_js("return execCommand(E[0]);") == "exo-open --launch TerminalEmulator"


def test_settings_defaults_agree_with_factory_and_qml():
    factory = json.loads((ROOT / "config" / "shell.default.json").read_text())["keybinds"]["overlay"]
    assert run_js("return DEFAULTS;") == factory
    qml = (ROOT / "config" / "KeybindsConfig.qml").read_text()
    props = dict(re.findall(r"property bool (\w+): (true|false)", qml))
    assert {k: v == "true" for k, v in props.items()} == factory
    assert run_js("return settings({runOnEnter: 'yes', compact: true});") == {**factory, "compact": True}


def test_overlay_surface_contract():
    text = OVERLAY.read_text()
    assert 'target: "keybinds"' in text
    for fn in ("function toggle()", "function open(query: string)", "function close()", "function isOpen()"):
        assert fn in text, fn
    assert 'name: "keybinds"' in text  # CustomShortcut hornero:keybinds
    assert "WlrLayer.Top" in text and "WlrKeyboardFocus.Exclusive" in text
    assert "hasFullscreenOnFocusedOutput()" in text  # never over a fullscreen game
    assert "Keybinds.endCapture()" in text  # closing never strands the capture submap
    shell = (ROOT / "shell.qml").read_text()
    assert "KeybindsOverlay {}" in shell


def test_sheet_keyboard_contract():
    text = SHEET.read_text()
    for key in ("Qt.Key_Return", "Qt.Key_Escape", "Qt.Key_Down", "Qt.Key_Up", "Qt.Key_E", "Qt.Key_D", "Qt.Key_Z"):
        assert key in text, key
    assert "Keybinds.settings.runOnEnter" in text and "Keybinds.settings.closeAfterRun" in text
    assert "Keybinds.beginCapture()" in text and "captureTimeout" in text
    assert "sheet.save(true)" in text  # swap on conflict
    assert "Glyph {" in text and "group.glyph" in text


def test_pane_exposes_every_overlay_setting():
    text = PANE.read_text()
    for key in ("runOnEnter", "closeAfterRun", "showSubmaps", "showMouse", "compact"):
        assert f'root.setOverlay("{key}"' in text, key
    assert "Reset overlay settings" in text and 'Undo.offerValues("keybinds-overlay"' in text
    assert "Keybinds.openOverlay(" in text


def test_keys_command_opens_the_overlay_over_ipc():
    ipc = (ROOT / "docs" / "IPC.md").read_text()
    assert "keybinds" in ipc
