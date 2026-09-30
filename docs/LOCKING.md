# Session-lock ownership

One session, one locker at a time. A second lock request issued while
another locker holds (or while the compositor still believes one does)
can kill quickshell outright — see shell#24.

## The two lockers

Hornero ships two session lockers with different owners:

- Shell lock (`modules/lock/`, `WlSessionLock`): the in-shell lock
  surface with PAM, notifications dock, media, and weather. Engaged by
  idle timeouts and logind signals (`modules/IdleMonitors.qml`), the
  `lock` shortcut, and `qs ipc call lock lock`.
- hyprlock (external backend): engaged by `horneroctl lock now` and
  `horneroctl power lock` (Settings and power tiles).

Idle lock is owned by the shell (`Config.general.idle.timeouts`, 180 s
default). hypridle must not invoke a second locker: its lock listener
was removed for exactly that reason.

## The rule

All in-shell acquisition goes through `Lock.requestLock()`
(`modules/lock/Lock.qml`), which:

1. no-ops while already locked or while a request is in flight;
2. refuses while `hyprlock` is running (single-locker policy);
3. fails open when the probe itself errors — a missing `pidof` must
   never wedge the lock shut.

No other file may write `locked = true`. The regression test
(`tests/test_lock_ownership.py`) enforces the single acquisition
point structurally.

## Why prevention, not handling

`WlSessionLock` exposes only `locked` — no error or failed signal
(verified in the installed `quickshell-wayland.qmltypes`). A failed
or reentrant acquisition is a fatal Wayland protocol error
(`invalid object`, connection terminates), uncatchable from QML.
No retry, timeout, or delay in the shell can mitigate it.

Upstream owner: quickshell#1054 (open) — fatal re-lock over an
orphaned ext-session-lock. Master carries afb2c27
("wayland/lock: guard against reentrancy during surface creation",
2026-08-25), which covers the reentrancy family but is in no
released quickshell yet (installed: 0.3.1, 2026-08-21). The
cross-locker orphan case (holder dies mid-lock, compositor state
stale) has no upstream fix; the single-locker policy above is the
Hornero-side containment until one lands.

## Recovery

If the shell dies to a lock fatal, restart it
(`horneroctl shell restart --yes`); the session itself survives.
Never run hyprlock and the shell lock in the same session on
purpose, and never re-request a lock while one is engaged.
