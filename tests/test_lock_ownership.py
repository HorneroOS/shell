"""Lock ownership: one session, one locker (shell#24).

All in-shell session-lock acquisition must route through
Lock.requestLock(); a raw `locked = true` write anywhere else is the
reentrant path that kills quickshell (upstream quickshell#1054).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK_QML = ROOT / "modules" / "lock" / "Lock.qml"
IDLE_QML = ROOT / "modules" / "IdleMonitors.qml"
DOC = ROOT / "docs" / "LOCKING.md"


def test_single_acquisition_point():
    """Only Lock.qml writes `locked = true`, inside requestLock's probe."""
    src = LOCK_QML.read_text()
    assert "function requestLock()" in src
    assert "foreignLockerProbe" in src
    # Exactly one acquisition write, in the probe's onExited handler.
    assert src.count("lock.locked = true") + src.count("lock.locked=true") == 1
    assert "if (!lock.locked)" in src
    # Redundant-request and in-flight guards present.
    assert "lockRequestPending" in src
    # Fail-open on probe error, refuse on foreign locker.
    assert "fail-open" in src or "fail open" in src
    assert "hyprlock" in src


def test_no_bypass_writes():
    """No QML outside Lock.qml acquires the session lock."""
    offenders = []
    for path in list((ROOT / "modules").rglob("*.qml")) + list(
        (ROOT / "services").rglob("*.qml")
    ):
        if path == LOCK_QML:
            continue
        text = path.read_text(errors="ignore")
        if "locked = true" in text or "locked=true" in text:
            offenders.append(str(path.relative_to(ROOT)))
    assert not offenders, f"lock acquisition outside requestLock(): {offenders}"


def test_idle_routes_through_guard():
    """Idle/logind lock paths call requestLock, never write directly."""
    src = IDLE_QML.read_text()
    assert "requestLock()" in src
    assert "locked = true" not in src and "locked=true" not in src


def test_policy_documented():
    """The ownership policy doc exists and names the upstream owner."""
    doc = DOC.read_text()
    assert "requestLock" in doc
    assert "1054" in doc
    assert "single-locker" in doc
