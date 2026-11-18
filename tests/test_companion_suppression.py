"""Companion suppression state machine (shell#652).

The rules live in modules/companion/suppression.js and run under node. The
regression: WlSessionLock does not emit `lockStateChanged` when `locked`
drops to false on unlock, so a notify-only sync latched `suppressLocked` at
true and Javi never reappeared. The getter is authoritative; the host
re-reads it on a slow poll while the flag is set.
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules" / "companion"
JS = COMP / "suppression.js"
HOST = (COMP / "CompanionHost.qml").read_text(encoding="utf-8")
STORE = (COMP / "CompanionStore.qml").read_text(encoding="utf-8")
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def run_js(body: str):
    script = JS.read_text(encoding="utf-8").replace(".pragma library", "") + "\n" + body
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


# Fake host: a lock whose getter changes with or without a notify, and the
# host reacting exactly like CompanionHost (notify -> sync, poll while set).
SIM = """
const lock = { locked: false };
let flag = false, polls = 0;
function sync() { const s = reconcileLock(flag, lock); if (s.changed) flag = s.flag; return s; }
function notify() { sync(); }
function tick() { if (flag) { polls++; sync(); } }
const log = [];
"""


@NODE
def test_unlock_without_notify_clears_the_latch_on_the_next_poll():
    r = run_js(SIM + """
lock.locked = true; notify(); log.push(flag);        // lock edge notifies
lock.locked = false;                                  // unlock: NO notify (#652)
log.push(flag); tick(); log.push(flag);
console.log(JSON.stringify({log, polls}));""")
    assert r["log"] == [True, True, False], "must latch until the poll, then clear"
    assert r["polls"] == 1


@NODE
def test_compositor_ended_lock_without_notify_also_clears():
    r = run_js(SIM + """
lock.locked = true; notify();
lock.locked = false;   // compositor finished the lock, no notify
tick();
console.log(JSON.stringify({flag}));""")
    assert r["flag"] is False


@NODE
def test_poll_is_idle_while_unlocked_and_notify_still_sets():
    r = run_js(SIM + """
tick(); tick(); const idle = polls;
lock.locked = true; notify();
console.log(JSON.stringify({idle, flag, poll: reconcileLock(flag, lock).poll}));""")
    assert r == {"idle": 0, "flag": True, "poll": True}


@NODE
def test_missing_lock_means_not_locked():
    r = run_js("""console.log(JSON.stringify([lockedNow(null), lockedNow(undefined), lockedNow({}), lockedNow({locked: 1})]));""")
    assert r == [False, False, False, False], "only a strict true counts"


@NODE
def test_every_input_suppresses_alone_and_reasons_are_reported():
    r = run_js("""
const names = ['locked','fullscreen','gameMode','areaPicker','controlCenter'];
const out = {none: isSuppressed(reasons({}))};
for (const n of names) { const i = {}; i[n] = true; out[n] = isSuppressed(reasons(i)); }
out.shape = Object.keys(reasons({})).join(',');
console.log(JSON.stringify(out));""")
    assert r["none"] is False
    for n in ("locked", "fullscreen", "gameMode", "areaPicker", "controlCenter"):
        assert r[n] is True, n
    assert r["shape"] == "locked,fullscreen,gameMode,areaPicker,controlCenter"


@NODE
def test_summon_visibility_rules():
    r = run_js("""console.log(JSON.stringify([
  isVisible(true, false, false, 'idle', false),
  isVisible(true, true, false, 'idle', false),
  isVisible(true, true, true, 'idle', false),
  isVisible(true, false, true, 'hidden', false),
  isVisible(false, false, false, 'idle', false)]));""")
    assert r == [True, False, True, False, False]


def test_host_syncs_from_notify_and_a_poll_that_only_runs_while_locked():
    assert "function onLockStateChanged()" in HOST
    assert "function onLockedChanged()" not in HOST
    assert "Suppression.reconcileLock(" in HOST
    assert "running: CompanionStore.suppressLocked" in HOST, "poll must be free while unlocked"
    assert "Suppression.LOCK_POLL_MS" in HOST


def test_store_exposes_suppressors_in_status():
    assert "Suppression.isSuppressed(root.suppressors)" in STORE
    assert "suppressors: root.suppressors" in STORE
