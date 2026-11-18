"""Full shell load gate: start the REAL shell.qml under real Quickshell.

qmllint does not compile QML the way the engine does, so a file the engine
rejects (for example a method named ``escape``, #665) passes lint and only
fails when Quickshell loads the shell. This test loads the whole shell.qml
with the installed Quickshell inside a private headless Wayland compositor
(sway with the wlroots headless backend, no window on any real display)
and fails on any QML load error.

Isolation: HOME, every XDG dir and XDG_RUNTIME_DIR point at fresh scratch
dirs, the session bus is a private dbus-daemon and the system bus address
points nowhere, so the run never reads or writes the user's config, never
talks to the user's compositor, PipeWire or D-Bus services, and never shows
anything on screen. The inherited WAYLAND_DISPLAY is ignored on purpose.

NOT RUN (skipped) without qs, sway and dbus-daemon. CI runs it in the
`shell-load` job (Arch Linux container, pinned archive snapshot).
"""
from __future__ import annotations

import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
QS = shutil.which("qs") or shutil.which("quickshell")
SWAY = shutil.which("sway")
DBUS = shutil.which("dbus-daemon")

LOAD_TIMEOUT = float(os.environ.get("HORNERO_SHELL_LOAD_TIMEOUT", "90"))
# Keep the shell up briefly after the load so errors raised while the root
# objects complete (Component.onCompleted, eager Loaders) are captured.
SETTLE_SECONDS = float(os.environ.get("HORNERO_SHELL_LOAD_SETTLE", "5"))

LOADED = "Configuration Loaded"
# Engine-level load failures. Any of these means a QML type did not load.
FAILURE_PATTERNS = [
    re.compile(p) for p in (
        r"Failed to load configuration",
        r"Type \S+ unavailable",
        r"is not a type",
        r"Illegal ",
        r"is not installed",
        r"module \"[^\"]+\" .*not installed",
        r"Expected token",
        r"Syntax ?Error",
        r"Cannot assign to non-existent",
        r"Invalid property assignment",
        r"Non-existent attached object",
        r"No such file or directory.*\.qml",
        r"Cannot load library",
        r"plugin cannot be loaded",
        r"failed to load component",
        r"Error loading QML",
    )
]
ANSI = re.compile(r"\x1b\[[0-9;]*m")

needs_stack = pytest.mark.skipif(
    not (QS and SWAY and DBUS),
    reason="NOT RUN: full shell load needs qs (Quickshell), sway (headless "
           "wlroots compositor) and dbus-daemon; CI job `shell-load` runs it",
)


def _wait_for(predicate, timeout: float, step: float = 0.1) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(step)
    return predicate()


def _stop(proc: subprocess.Popen | None) -> None:
    if proc is None or proc.poll() is not None:
        return
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=10)


def _base_env(tmp_path: Path, runtime: Path) -> dict[str, str]:
    dirs = {name: tmp_path / name for name in ("home", "config", "state", "data", "cache")}
    for path in dirs.values():
        path.mkdir(parents=True, exist_ok=True)
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": str(dirs["home"]),
        "XDG_CONFIG_HOME": str(dirs["config"]),
        "XDG_STATE_HOME": str(dirs["state"]),
        "XDG_DATA_HOME": str(dirs["data"]),
        "XDG_CACHE_HOME": str(dirs["cache"]),
        "XDG_RUNTIME_DIR": str(runtime),
        "XDG_DATA_DIRS": "/usr/local/share:/usr/share",
        "XDG_CONFIG_DIRS": "/etc/xdg",
        "LANG": "C.UTF-8",
        "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=/nonexistent/hornero-load-test",
    }
    # Opt-in import path for a plugin built in-tree instead of installed.
    if os.environ.get("QML_IMPORT_PATH"):
        env["QML_IMPORT_PATH"] = os.environ["QML_IMPORT_PATH"]
    return env


def _failures(log: str) -> list[str]:
    return [ln for ln in log.splitlines() if any(p.search(ln) for p in FAILURE_PATTERNS)]


def test_failure_patterns_catch_the_665_class_of_error():
    # The exact Quickshell output of #665 must trip the gate.
    sample = (
        " ERROR: Failed to load configuration\n"
        " ERROR:   caused by @modules/companion/CompanionStore.qml[12:5]: "
        "Type JaviRadio unavailable\n"
        " ERROR:   caused by @modules/companion/JaviRadio.qml[124:14]: "
        "Illegal method name\n"
    )
    assert len(_failures(sample)) == 3
    assert not _failures(" INFO: Configuration Loaded\n WARN qml: no hyprland socket\n")


@needs_stack
def test_full_shell_loads_without_qml_errors(tmp_path):
    # XDG_RUNTIME_DIR holds unix sockets (Wayland, Quickshell IPC) whose
    # paths must stay under the 108-byte sun_path limit, so it lives in a
    # short private temp dir, removed afterwards; nothing durable goes there.
    runtime = Path(tempfile.mkdtemp(prefix="hsl-"))
    runtime.chmod(0o700)
    env = _base_env(tmp_path, runtime)
    log_dir = tmp_path / "logs"
    log_dir.mkdir()
    dbus = sway = shell = None
    try:
        dbus = subprocess.Popen(
            [DBUS, "--session", "--nofork", "--nopidfile", "--print-address=1",
             f"--address=unix:path={runtime / 'bus'}"],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
        address = dbus.stdout.readline().strip()
        assert address, "private dbus-daemon did not start"
        env["DBUS_SESSION_BUS_ADDRESS"] = address

        sway_conf = tmp_path / "sway.conf"
        sway_conf.write_text("output HEADLESS-1 resolution 1920x1080\n", encoding="utf-8")
        sway_env = dict(env, WLR_BACKENDS="headless", WLR_RENDERER="pixman",
                        WLR_LIBINPUT_NO_DEVICES="1", WLR_HEADLESS_OUTPUTS="1")
        sway_log = (log_dir / "sway.log").open("w", encoding="utf-8")
        sway = subprocess.Popen([SWAY, "--unsupported-gpu", "-c", str(sway_conf)],
                                env=sway_env, stdout=sway_log, stderr=subprocess.STDOUT)
        socket_ready = _wait_for(lambda: any(runtime.glob("wayland-*[0-9]")), 20)
        assert socket_ready and sway.poll() is None, (
            "headless sway did not start:\n" + (log_dir / "sway.log").read_text(encoding="utf-8")[-4000:])
        wayland = sorted(p.name for p in runtime.glob("wayland-*[0-9]"))[0]

        shell_env = dict(env, WAYLAND_DISPLAY=wayland, QT_QPA_PLATFORM="wayland",
                         QT_QUICK_BACKEND="software")
        shell_log_path = log_dir / "shell.log"
        shell_log = shell_log_path.open("w", encoding="utf-8")
        shell = subprocess.Popen([QS, "--no-color", "-p", str(ROOT / "shell.qml")],
                                 env=shell_env, cwd=tmp_path, stdout=shell_log,
                                 stderr=subprocess.STDOUT)

        def outcome() -> bool:
            text = shell_log_path.read_text(encoding="utf-8", errors="replace")
            return LOADED in text or "Failed to load configuration" in text or shell.poll() is not None

        _wait_for(outcome, LOAD_TIMEOUT, step=0.25)
        if shell.poll() is None:
            time.sleep(SETTLE_SECONDS)
        alive = shell.poll() is None
    finally:
        _stop(shell)
        _stop(sway)
        _stop(dbus)
        shutil.rmtree(runtime, ignore_errors=True)

    log = ANSI.sub("", shell_log_path.read_text(encoding="utf-8", errors="replace"))
    artifact = os.environ.get("HORNERO_SHELL_LOAD_LOG")
    if artifact:
        Path(artifact).write_text(log, encoding="utf-8")
    tail = "\n".join(log.splitlines()[-80:])
    failures = _failures(log)
    assert not failures, "shell.qml failed to load:\n" + "\n".join(failures[:40]) + "\n--- log tail ---\n" + tail
    assert LOADED in log, f"no '{LOADED}' within {LOAD_TIMEOUT:.0f}s:\n{tail}"
    assert alive, f"shell exited within {SETTLE_SECONDS:.0f}s of loading:\n{tail}"
