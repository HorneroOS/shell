"""Companion reactions: pure policy (node) plus the QML wiring contract.

The policy in modules/companion/reactions.js decides whether a real event
makes Javi react. It runs under node here; the QML bus, store, IPC and the
native emitters are asserted structurally (no compositor needed).
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules" / "companion"
JS = COMP / "reactions.js"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def run_js(body: str):
    script = JS.read_text(encoding="utf-8").replace(".pragma library", "") + "\n" + body
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


BASE = "let S = defaults(); const H = emptyHistory(); const NOW = 1000000;"


def decide(extra: str, kind="notification", source="'shell'", mode="'everyday'", minute=720, text="''"):
    return run_js(BASE + extra + f"""
console.log(JSON.stringify(decide({{settings: S, kind: '{kind}', source: {source}, text: {text},
  mode: {mode}, nowMs: NOW, minute: {minute}, history: typeof HH === 'undefined' ? H : HH,
  hasAnimation: function () {{ return true; }}}})));""")


@NODE
def test_native_event_reacts_in_everyday():
    r = decide("", kind="battery.low")
    assert r["ok"] and r["anim"] == "worry" and r["bubble"] == "Battery is getting low."


@NODE
def test_unknown_kind_and_bad_source_rejected():
    assert decide("", kind="nope")["reason"] == "unknown-kind"
    assert decide("", source="'evil'")["reason"] == "invalid-source"
    assert decide("", source="'plugin:../x'")["reason"] == "invalid-source"


@NODE
def test_external_sources_cannot_raise_native_kinds():
    assert decide("", kind="battery.critical", source="'plugin:evil'")["reason"] == "native-only"
    assert decide("", kind="battery.critical", source="'ipc'")["reason"] == "native-only"
    assert decide("", kind="build.done", source="'plugin:ci'")["ok"] is True


@NODE
def test_master_switch_and_per_kind_switch():
    assert decide("S.enabled = false;")["reason"] == "disabled"
    assert decide("S.kindsOff = ['notification'];")["reason"] == "kind-off"
    assert decide("S.kindsOff = ['notification'];", kind="build.done")["ok"] is True


@NODE
def test_mode_behaviour_gaming_silent_focus_quiet():
    assert decide("", mode="'gaming'")["reason"] == "mode-silent"
    assert decide("", mode="'focus'")["reason"] == "mode-quiet"
    # Important kinds survive quiet, but never carry a bubble.
    r = decide("", kind="battery.critical", mode="'focus'")
    assert r["ok"] and r["bubble"] == "" and r["anim"] == "worry"
    assert decide("", kind="battery.critical", mode="'gaming'")["reason"] == "mode-silent"


@NODE
def test_user_can_override_mode_level_and_invalid_levels_are_ignored():
    assert decide("S.modeBehaviour.gaming = 'full';", mode="'gaming'")["ok"] is True
    assert decide("S = sanitizeSettings({modeBehaviour:{gaming:'loud'}});", mode="'gaming'")["reason"] == "mode-silent"


@NODE
def test_quiet_hours_wrap_midnight_and_only_quieten():
    q = "S.quietHours = {enabled: true, start: '22:00', end: '07:00'};"
    assert decide(q, kind="build.done", minute=23 * 60)["reason"] == "mode-quiet"
    assert decide(q, kind="build.done", minute=3 * 60)["reason"] == "mode-quiet"
    assert decide(q, kind="build.done", minute=12 * 60)["ok"] is True
    assert decide(q, kind="battery.critical", minute=23 * 60)["ok"] is True
    # start == end is an empty window, not "always".
    assert decide("S.quietHours = {enabled: true, start: '09:00', end: '09:00'};", minute=9 * 60)["ok"] is True
    # Quiet hours never loosen a silent mode.
    assert decide(q, mode="'gaming'", minute=12 * 60)["reason"] == "mode-silent"


@NODE
def test_bubbles_switch_keeps_animation():
    r = decide("S.bubbles = false;", kind="battery.low")
    assert r["ok"] and r["bubble"] == "" and r["anim"] == "worry"


@NODE
def test_cooldown_and_global_rate_limit():
    hist = "var HH = record(H, 'notification', 'shell', NOW - 1000);"
    assert decide(hist)["reason"] == "cooldown"
    many = "var HH = {lastByKind: {}, recent: [NOW-1,NOW-2,NOW-3,NOW-4,NOW-5,NOW-6], bySource: {}};"
    assert decide(many, kind="download.done", source="'ipc'")["reason"] == "rate-limit"
    # Important events skip the global limit.
    assert decide(many, kind="battery.critical")["ok"] is True


@NODE
def test_per_source_rate_limit_and_muting():
    src = "var HH = {lastByKind: {}, recent: [], bySource: {'plugin:ci': [NOW-1000, NOW-2000, NOW-3000]}};"
    assert decide(src, kind="build.done", source="'plugin:ci'")["reason"] == "source-rate-limit"
    assert decide(src, kind="build.done", source="'plugin:other'")["ok"] is True
    assert decide("S.mutedSources = ['plugin:ci'];", kind="build.done", source="'plugin:ci'")["reason"] == "source-muted"


@NODE
def test_external_text_is_plain_bounded_and_single_line():
    r = decide("", kind="build.done", source="'plugin:ci'", text="'<b>Done</b>\\n\\u202e' + 'x'.repeat(200)")
    assert r["ok"] and len(r["bubble"]) <= 80
    assert "\n" not in r["bubble"] and "‮" not in r["bubble"]
    # Empty text falls back to the built-in line; shell text is never custom.
    assert decide("", kind="build.done", source="'plugin:ci'", text="'  '")["bubble"] == "Build finished."


@NODE
def test_missing_animation_degrades_without_failing_when_bubble_exists():
    r = run_js(BASE + """console.log(JSON.stringify(decide({settings: S, kind: 'build.done', source: 'ipc', text: '',
      mode: 'everyday', nowMs: NOW, minute: 700, history: H, hasAnimation: function () { return false; }})));""")
    assert r["ok"] and r["anim"] == "" and r["bubble"] == "Build finished."
    r = run_js(BASE + """console.log(JSON.stringify(decide({settings: S, kind: 'notification', source: 'shell', text: '',
      mode: 'everyday', nowMs: NOW, minute: 700, history: H, hasAnimation: function () { return false; }})));""")
    assert r["reason"] == "nothing-to-show"


@NODE
def test_sanitize_settings_repairs_garbage():
    r = run_js("""console.log(JSON.stringify(sanitizeSettings({enabled: 'yes', kindsOff: ['x', 'build.done', 'build.done'],
      quietHours: {enabled: true, start: '25:00', end: '6:30'}, mutedSources: ['plugin:ok', '../bad', 5]})));""")
    assert r["enabled"] is True and r["kindsOff"] == ["build.done"]
    assert r["quietHours"] == {"enabled": True, "start": "22:00", "end": "06:30"}
    assert r["mutedSources"] == ["plugin:ok"]
    assert run_js("console.log(JSON.stringify(sanitizeSettings(null)))") == run_js("console.log(JSON.stringify(defaults()))")


@NODE
def test_every_kind_uses_a_shipped_animation():
    manifest = json.loads((ROOT / "assets/companion/manifest.json").read_text())
    shipped = set(manifest["skins"]["default"]["animations"])
    anims = run_js("console.log(JSON.stringify(Object.keys(KINDS).map(function (k) { return KINDS[k].anim; })))")
    assert set(anims) <= shipped


# -- QML wiring contract ---------------------------------------------------

STORE = (COMP / "CompanionStore.qml").read_text()
BUS = (COMP / "CompanionReactions.qml").read_text()
HOST = (COMP / "CompanionHost.qml").read_text()


def test_bus_is_a_singleton_that_only_decides_through_the_policy():
    assert "pragma Singleton" in BUS and "Reactions.decide(" in BUS
    assert "CompanionStore.playReaction(" in BUS
    for banned in ("Timer {", "Process {", "NumberAnimation"):
        assert banned not in BUS, f"bus must stay idle-free: {banned}"


def test_store_persists_reactions_and_never_interrupts_tasks():
    assert "property string reactions" in STORE
    assert "reactions: persist.reactions" in STORE
    assert "function playReaction(" in STORE
    body = STORE.split("function playReaction(")[1].split("\n    }\n")[0]
    assert "root.visible" in body and "settled" in body and "priority >= 3" in body


def test_native_emitters_are_wired_to_real_events():
    assert "signal received(bool critical)" in (ROOT / "services/Notifs.qml").read_text()
    assert "root.received(critical)" in (ROOT / "services/Notifs.qml").read_text()
    bat = (ROOT / "modules/BatteryMonitor.qml").read_text()
    for kind in ("charger.plugged", "charger.unplugged", "battery.critical", "battery.low"):
        assert kind in bat
    assert 'react("notification", "shell"' in HOST
    assert "Experience.stateReady" in HOST


def test_ipc_react_is_governed_and_labelled_ipc():
    assert "function react(kind: string, text: string)" in HOST
    assert '"ipc"' in HOST and "function reactStatus()" in HOST


def test_bubble_renders_untrusted_text_as_plain_text():
    bubble = (COMP / "Bubble.qml").read_text()
    assert bubble.count("textFormat: Text.PlainText") == 2


def test_control_center_exposes_every_reaction_knob():
    pane = (ROOT / "modules/controlcenter/companion/CompanionPane.qml").read_text()
    assert 'title: qsTr("Reactions")' in pane
    for needle in ("patchReactions(\"enabled\"", "patchReactions(\"bubbles\"", "setKindEnabled(",
                   "setModeBehaviour(", "setQuietHours(\"enabled\"", "setQuietHours(\"start\"",
                   "setQuietHours(\"end\"", "setReactionSettings({})", "CompanionReactions.catalog",
                   "CompanionReactions.modeIds"):
        assert needle in pane, needle
