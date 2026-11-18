"""Plugin hosts must not write the list they are built from while it notifies.

A Loader reports `Loading` synchronously while its Repeater delegate is
created, and that creation runs inside the change notification of the host
list (StableList.source, PluginDesktopWidgets.deckEntries) derived from
Plugins.entries. Plugins.markLoading used to republish `entries` from there,
so on a real host every plugin start logged `Binding loop detected for
property "deckEntries"` (36x) and `... "source"` (StableList, bar and
launcher hosts) from the first run with PluginKit apiLevel 4 hosts.

The runtime test runs the real hosts offscreen over fixture plugins (isolated
XDG, a horneroctl double) and fails on any QML binding-loop or TypeError
warning; it is skipped, never faked, without quickshell.
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs

SERVICE = (ROOT / "services" / "Plugins.qml").read_text()
FIXTURES = ROOT / "tests" / "fixtures" / "plugin_loops"


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    depth = 0
    for i in range(source.index("{", start), len(source)):
        depth += {"{": 1, "}": -1}.get(source[i], 0)
        if depth == 0:
            return source[start:i + 1]
    raise AssertionError(f"unterminated {signature}")


def test_mark_loading_never_republishes_entries():
    body = _function_body(SERVICE, "function markLoading(")
    assert "root.entries =" not in body, "markLoading runs inside the host list's own notification"
    assert "root.hostLoadClock = " in body


def test_load_clock_is_not_part_of_entries():
    assert "hostLoadStartedAtMs:" not in _function_body(SERVICE, "function markLoading(")
    assert "root.hostLoadClock = ({})" in SERVICE, "a new discovery restarts the clock"


@requires_qs
def test_hosts_start_without_binding_loops(tmp_path: Path):
    root = tmp_path / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests" / "qml" / "plugin_loops" / "harness.qml", root / "shell.qml")

    xdg = tmp_path / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    shutil.copytree(FIXTURES / "plugins", xdg / "data" / "hornero" / "plugins")
    (xdg / "config" / "hornero" / "shell.json").write_text((ROOT / "config" / "shell.default.json").read_text())
    (xdg / "state" / "hornero" / "experience.json").write_text(json.dumps({
        "schemaVersion": 1, "mode": "signal", "previous": "everyday", "source": "user",
        "auto": False, "changedAt": "2026-11-17T00:00:00Z", "studioAudioRestore": ""}))
    bindir = tmp_path / "bin"
    bindir.mkdir()
    (bindir / "horneroctl").symlink_to(FIXTURES / "fake-horneroctl.sh")

    env = {
        "PATH": f"{bindir}:{os.environ['PATH']}",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"),
        "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": str(root / "plugin" / "qml"),
        "QT_QPA_PLATFORM": "offscreen",
        "LIBGL_ALWAYS_SOFTWARE": "1",
    }
    proc = subprocess.run(
        ["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
        capture_output=True, text=True, timeout=90, env=env, cwd=tmp_path,
    )
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)

    lines = [ln for ln in log.splitlines() if "PLOOPS " in ln]
    assert lines, f"harness never reported:\n{log[-2000:]}"
    report = json.loads(lines[-1].split("PLOOPS ", 1)[1])
    # Not vacuous: every host really instantiated its fixtures.
    assert report["mode"] == "signal"
    assert report["deck"] == 2 and report["bar"] == 1 and report["launcher"] == 1, report
    assert all(s.endswith(":loaded") for s in report["states"]), report

    bad = [ln for ln in log.splitlines() if "Binding loop" in ln or "TypeError" in ln]
    assert not bad, "\n".join(bad[:10])
