"""Bar section order editor in the Bars pane (shell#466). The pure logic in
barorder.js edits the active layout (bar.bars or a perScreen override) in
the same shape presets write, keeping options and unknown fields."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TASKBAR = ROOT / "modules/controlcenter/taskbar"
JS = TASKBAR / "barorder.js"

BARS = [{
    "edge": "top", "style": "islands", "margin": 10, "custom": {"keep": True},
    "groups": {
        "start": [{"id": "logo", "enabled": True},
                  {"id": "quickActions", "enabled": True, "options": {"actions": ["screenshot"]}}],
        "center": ["clock"],
        "end": [{"id": "tray", "enabled": True}, {"id": "power", "enabled": False}],
    },
}]


def run(expr):
    node = shutil.which("node")
    assert node, "node is required to execute barorder.js"
    src = JS.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + f"\nconsole.log(JSON.stringify({expr}));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def ids(bar, group):
    return [e["id"] for e in bar["groups"][group]]


B = json.dumps(BARS)


def test_move_within_a_group_keeps_options_and_unknown_fields():
    out = run(f"move({B}, 0, 'start', 1, -1)")
    assert ids(out[0], "start") == ["quickActions", "logo"]
    assert out[0]["groups"]["start"][0]["options"] == {"actions": ["screenshot"]}
    assert out[0]["custom"] == {"keep": True} and out[0]["style"] == "islands"
    assert ids(out[0], "center") == ["clock"]  # string entries normalised


def test_move_crosses_into_neighbouring_groups_and_stops_at_the_ends():
    out = run(f"move({B}, 0, 'start', 1, 1)")
    assert ids(out[0], "start") == ["logo"] and ids(out[0], "center") == ["quickActions", "clock"]
    out = run(f"move({B}, 0, 'end', 0, -1)")
    assert ids(out[0], "center") == ["clock", "tray"] and ids(out[0], "end") == ["power"]
    assert run(f"move({B}, 0, 'start', 0, -1)")[0]["groups"]["start"][0]["id"] == "logo"
    assert run(f"canMove({B}, 0, 'start', 0, -1)") is False
    assert run(f"canMove({B}, 0, 'end', 1, 1)") is False
    assert run(f"canMove({B}, 0, 'end', 0, -1)") is True


def test_toggle_and_add_sections():
    out = run(f"setEnabled({B}, 0, 'end', 1, true)")
    assert out[0]["groups"]["end"][1]["enabled"] is True
    missing = run(f"missingIds({B}, 0)")
    assert "extensions" in missing and "logo" not in missing and "clock" not in missing
    out = run(f"addEntry({B}, 0, 'end', 'extensions')")
    assert ids(out[0], "end") == ["tray", "power", "extensions"]
    assert ids(run(f"addEntry({B}, 0, 'end', 'logo')")[0], "end") == ["tray", "power"]


def test_per_screen_overrides_are_edited_in_place():
    per = json.dumps([{"screen": "DP-1", "bars": BARS}, {"screen": "HDMI-A-1", "bars": []}])
    assert run(f"overrideScreens({per})") == ["DP-1"]
    edited = run(f"move(barsForScope([], {per}, 'DP-1'), 0, 'start', 1, -1)")
    out = run(f"withScreenBars({per}, 'DP-1', {json.dumps(edited)})")
    assert ids(out[0]["bars"][0], "start") == ["quickActions", "logo"]
    assert out[1] == {"screen": "HDMI-A-1", "bars": []}


def test_group_titles_follow_bar_orientation():
    assert run("groupTitle('left', 'start')") == "Top"
    assert run("groupTitle('top', 'end')") == "Right"


def test_catalogue_matches_the_bar_entries():
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    for entry in run("Object.keys(ENTRIES)"):
        assert f'roleValue: "{entry}"' in bar, entry


def test_editor_lives_in_the_bars_pane_and_saves_the_active_layout():
    pane = (TASKBAR / "TaskbarPane.qml").read_text(encoding="utf-8")
    editor = (TASKBAR / "BarOrderEditor.qml").read_text(encoding="utf-8")
    assert 'import "."' in pane and "BarOrderEditor {" in pane
    assert "Config.bar.bars = next;" in editor
    assert "Config.bar.perScreen = BarOrder.withScreenBars(" in editor
    assert "Config.save();" in editor
