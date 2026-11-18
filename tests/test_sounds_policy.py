"""Event sound policy (services/sounds.js) and its wiring."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "sounds.js"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def run(body: str):
    script = JS.read_text().replace(".pragma library", "") + "\n" + body
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


BASE = "{enabled: true, eventOn: true, quiet: false, critical: false, hints: {}, alwaysChime: false, now: 10000, last: 0}"


def decide(event: str, **over):
    extra = ", ".join(f"{k}: {json.dumps(v)}" for k, v in over.items())
    return run(f"var o = Object.assign({BASE}, {{{extra}}}); console.log(JSON.stringify(decide('{event}', o)))")


@NODE
def test_gates_and_hints():
    assert decide("notification") == {"play": True, "reason": ""}
    assert decide("notification", enabled=False)["reason"] == "disabled"
    assert decide("notification", eventOn=False)["reason"] == "event-off"
    assert decide("notification", quiet=True)["reason"] == "quiet"
    assert decide("notification", hints={"suppress-sound": True})["reason"] == "suppress-sound"
    assert decide("notification", hints={"suppress-sound": True}, alwaysChime=True)["reason"] == "suppress-sound"
    assert decide("notification", hints={"sound-name": "message"})["reason"] == "app-sound"
    assert decide("notification", hints={"sound-file": "/x.oga"})["reason"] == "app-sound"
    assert decide("notification", hints={"sound-name": "message"}, alwaysChime=True)["play"] is True
    assert decide("bogus")["reason"] == "unknown-event"


@NODE
def test_quiet_modes_cover_battery_and_charger_but_critical_battery_overrides():
    assert decide("charger", quiet=True)["reason"] == "quiet"
    assert decide("battery", quiet=True)["reason"] == "quiet"
    assert decide("battery", quiet=True, critical=True)["play"] is True
    assert decide("charger", quiet=True, critical=True)["reason"] == "quiet"


@NODE
def test_rate_limit_per_kind():
    assert decide("notification", now=10000, last=9700)["reason"] == "rate-limited"
    assert decide("notification", now=10000, last=9500)["play"] is True


@NODE
def test_theme_names_and_fallback():
    out = run("""console.log(JSON.stringify([cleanTheme('..'), cleanTheme('a/b'), cleanTheme('x..y'), cleanTheme('.hidden'),
      cleanTheme('ocean'), cleanTheme(null), candidates('ocean', 'notification'), candidates('../etc', 'battery'),
      candidates('freedesktop', 'charger'), candidates('ocean', 'nope'), exitReason(0), exitReason(3), exitReason(4), exitReason(1)]))""")
    assert out[:6] == ["", "", "", "", "ocean", ""]
    assert out[6] == ["/usr/share/sounds/ocean/stereo/message-new-instant.oga", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"]
    assert out[7] == ["/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"]
    assert out[8] == ["/usr/share/sounds/freedesktop/stereo/power-plug.oga"]
    assert out[9] == [] and out[10:] == ["", "no-file", "no-player", "failed"]


def test_wiring():
    svc = (ROOT / "services" / "Sounds.qml").read_text()
    assert 'import "sounds.js" as Model' in svc and "Model.decide(" in svc
    assert "proc.running" in svc, "one process per kind never overlaps"
    assert "execDetached" not in svc
    notifs = (ROOT / "services" / "Notifs.qml").read_text()
    assert 'Sounds.play("notification", held || props.dnd, false, notif.hints' in notifs
    bat = (ROOT / "modules" / "BatteryMonitor.qml").read_text()
    assert bat.count("Notifs.dnd || Experience.holdPopups") == 2
    assert 'Sounds.play("battery", Notifs.dnd || Experience.holdPopups, chimeCritical, null)' in bat
    loop = bat[bat.index("for (const level of root.warnLevels) {\n                if (p <="):bat.index("if (chime)")]
    assert "Sounds.play" not in loop, "one chime per percentage change, not one per level"
    panel = (ROOT / "modules" / "controlcenter" / "notifications" / "SoundsPanel.qml").read_text()
    assert "FolderListModel" not in panel and "Sounds.themes" in panel and "Sounds.previewStatus" in panel
    assert "Config.sounds.alwaysChime" in panel
    assert json.loads((ROOT / "config" / "shell.default.json").read_text())["sounds"]["alwaysChime"] is False
