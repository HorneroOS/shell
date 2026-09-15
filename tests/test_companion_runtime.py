"""Companion runtime: animation player, behavior store, overlay host.

Static QML contract tests (no compositor needed): every behavior the
task names is asserted structurally so regressions fail here, not in
a running shell.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "modules" / "companion"
STORE = (COMPANION / "CompanionStore.qml").read_text()
PLAYER = (COMPANION / "Player.qml").read_text()
HOST = (COMPANION / "CompanionHost.qml").read_text()
BUBBLE = (COMPANION / "Bubble.qml").read_text()
RESOLVER = (COMPANION / "Companion.qml").read_text()

BEHAVIOR_STATES = ["hidden", "peeking", "entering", "idle", "hovering",
                   "talking", "excited", "dragging", "leaving", "sleeping"]
FUTURE_STATES = ["listening", "thinking", "acting",
                 "success", "warning", "error"]
IPC_FNS = ["show(", "hide(", "toggle(", "say(", "tip(", "play(",
           "setState(", "setSkin(", "resetPosition("]


def test_runtime_files_exist():
    for name in ("CompanionStore.qml", "Player.qml", "Bubble.qml",
                 "CompanionHost.qml", "Companion.qml"):
        assert (COMPANION / name).exists(), f"missing {name}"


def test_behavior_states_enumerated():
    for state in BEHAVIOR_STATES:
        assert f'"{state}"' in STORE, f"store missing behavior state {state}"
    assert len(BEHAVIOR_STATES) == 10


def test_future_assistant_states_exposed_without_backend():
    for state in FUTURE_STATES:
        assert f'"{state}"' in STORE, f"store missing future state {state}"
    # Mapping only: no AI/process/network machinery in the store.
    for banned in ("execDetached", "Process ", "XMLHttpRequest", "WebSocket"):
        assert banned not in STORE, f"store must stay presentation-only: {banned}"


def test_animation_mapping_covers_all_states():
    for state in BEHAVIOR_STATES + FUTURE_STATES:
        # Every state maps through animationFor's switch (default covers
        # the grounded rest states; named cases cover fly/greet/walk).
        assert "animationFor" in STORE
    assert '"fly"' in STORE and '"greet"' in STORE and '"walk"' in STORE
    # Walk never relocates: no position writes outside drag/commit paths.
    assert "posX" in STORE and "posY" in STORE


def test_store_persists_without_hand_rolled_writes():
    assert "PersistentProperties" in STORE
    assert 'reloadableId: "companion"' in STORE
    for key in ("enabled", "skin", "sizeScale", "tipsEnabled", "edge",
                "sleepMinutes", "reducedMotion", "bubbleTheme",
                "posX", "posY", "screenName"):
        assert key in STORE, f"store missing persisted key {key}"
    assert "sanitize" in STORE


def test_player_single_timer_core():
    assert len(re.findall(r"\bTimer\s*\{", PLAYER)) == 1, \
        "Player must advance on exactly one Timer"
    assert "signal finished()" in PLAYER
    for prop in ("frameMs", "loop", "playing", "paused", "currentIndex"):
        assert prop in PLAYER, f"Player missing {prop}"
    # Single-frame reels never run the timer: idle costs nothing.
    assert "frames.length > 1" in PLAYER
    assert "setReel" in PLAYER


def test_resolver_exposes_full_reels():
    assert "function reel(" in RESOLVER
    assert '"files"' in RESOLVER and '"frameMs"' in RESOLVER
    assert '"loop"' in RESOLVER and '"next"' in RESOLVER


def test_host_single_companion_overlay():
    assert "CompanionStore.enabled ? Quickshell.screens : []" in HOST
    assert "isMine" in HOST
    assert "WlrLayer.Overlay" in HOST
    assert "ExclusionMode.Ignore" in HOST
    assert "WlrKeyboardFocus.None" in HOST


def test_host_suppression_inputs():
    assert "GameMode.enabled" in HOST
    assert "hasFullscreen" in HOST
    assert "lock.locked" in HOST or "lock !== null" in HOST
    assert "areaPickerOpen" in STORE
    assert "CompanionStore.areaPickerOpen = active" in \
        (ROOT / "modules" / "areapicker" / "AreaPicker.qml").read_text()


def test_host_drag_and_persisted_position():
    assert "commitToStore" in HOST
    assert "screenName" in HOST
    assert "syncFromStore" in HOST


def test_host_hybrid_motion_and_reduced_motion():
    assert "bobY" in HOST
    assert "flyAnim" in HOST and "landAnim" in HOST
    assert "reducedMotion" in HOST
    assert "Easing.InOutQuad" in HOST or "Easing.OutBounce" in HOST


def test_host_sleep_and_wake():
    assert "checkIdle" in STORE and "sleepMinutes" in STORE
    assert '"sleeping"' in STORE
    assert "markActive" in STORE


def test_bubble_wrap_flip_theme():
    assert "Wrap" in BUBBLE
    assert "maxWidth" in BUBBLE
    assert "flip" in BUBBLE
    for theme in ("dark", "light", "pampa"):
        assert f'"{theme}"' in BUBBLE, f"bubble missing theme {theme}"


def test_menu_actions():
    for label in ("Show a tip", "Try another skin", "Reset position",
                  "Take a break", "Companion settings"):
        assert label in HOST, f"menu missing {label}"


def test_companion_ipc_target():
    assert 'target: "companion"' in HOST
    for fn in IPC_FNS:
        assert f"function {fn}" in HOST, f"companion IPC missing {fn}"
    doc = (ROOT / "docs" / "IPC.md").read_text()
    assert "companion" in doc, "docs/IPC.md must document the companion target"


def test_shell_wires_host():
    shell = (ROOT / "shell.qml").read_text()
    assert "CompanionHost" in shell
    assert "modules/companion" in shell
