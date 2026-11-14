"""Supervised standalone lock process contract (shell#257).

The session lock surface used to live only in the main shell process,
so any shell crash/kill while locked stranded the compositor lock
with no living client (reproduced live on colibri, 2026-11-14). The
staged fix is a lock-only quickshell entrypoint supervised by systemd,
opt-in via HORNERO_EXTERNAL_LOCK=1, with exactly one lock owner.

Static contract in repo style: lock.qml binds the full shell config
(qs.* singletons), so it is not loadable under plain qmltestrunner;
this suite pins the structure, and live lock testing is deliberately
never done from automation (we do not lock/unlock user sessions).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK_MAIN = ROOT / "lock.qml"
SHELL_MAIN = ROOT / "shell.qml"
LOCK_QML = ROOT / "modules" / "lock" / "Lock.qml"
IDLE_QML = ROOT / "modules" / "IdleMonitors.qml"
UNIT = ROOT / "assets" / "hornero-lock.service"
CMAKE = ROOT / "CMakeLists.txt"
DOC = ROOT / "docs" / "LOCKING.md"


def test_lock_entrypoint_is_lock_only():
    src = LOCK_MAIN.read_text()
    assert "Lock {" in src
    assert "IdleMonitors {" in src
    assert "lockOnly: true" in src
    assert "lockOwner: true" in src
    # No desktop surface may ride along into the lock process.
    for forbidden in ("Drawers", "Background", "PluginHost", "CompanionHost", "PolkitHost"):
        assert forbidden not in src, forbidden


def test_single_owner_guard():
    src = LOCK_QML.read_text()
    assert "property bool lockOwner: true" in src
    assert "if (!lockOwner)" in src
    # requestLock stays the only acquisition write (see
    # test_lock_ownership.py) and the guard precedes it.
    guard = src.index("if (!lockOwner)")
    acquire = src.index("lock.locked = true")
    assert guard < acquire


def test_main_shell_delegates_only_when_opted_in():
    src = SHELL_MAIN.read_text()
    assert 'Quickshell.env("HORNERO_EXTERNAL_LOCK")' in src
    assert "lockOwner: !externalLock" in src
    # Default path unchanged: the in-shell Lock is still instantiated.
    assert "Lock {" in src


def test_idle_monitors_lock_only_filter():
    src = IDLE_QML.read_text()
    assert "property bool lockOnly: false" in src
    assert 'action !== "lock" && action !== "unlock"' in src


def test_supervised_unit():
    unit = UNIT.read_text()
    assert "Restart=on-failure" in unit
    assert "lock.qml" in unit
    assert "graphical-session.target" in unit


def test_packaging_ships_but_never_enables():
    cmake = CMAKE.read_text()
    assert "lock.qml" in cmake
    assert "hornero-lock.service" in cmake
    # Shipped != enabled: no install-time enablement hook.
    assert "systemctl" not in cmake
    assert "enable" not in UNIT.read_text().lower().split("[install]")[0]


def test_docs_describe_opt_in_pair():
    doc = " ".join(DOC.read_text().split())
    assert "hornero-lock.service" in doc
    assert "HORNERO_EXTERNAL_LOCK=1" in doc
    assert "never enabled by the package" in doc
