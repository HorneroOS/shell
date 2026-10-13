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
(verified in the installed `quickshell-wayland.qmltypes`). Before
Quickshell 0.3.2, a failed or reentrant acquisition could take a fatal
Wayland path (`invalid object`, connection terminates), uncatchable
from QML. Version 0.3.2 guards that known failed-acquisition path,
but QML still cannot repair an orphaned compositor lock. No retry,
timeout, or delay in the shell can mitigate protocol state owned by
the compositor.

Upstream owner: [quickshell#1054](https://github.com/quickshell-mirror/quickshell/issues/1054)
(open) — fatal re-lock over an orphaned ext-session-lock.
[Quickshell 0.3.2](https://github.com/quickshell-mirror/quickshell/releases/tag/v0.3.2)
(released 2026-10-08) includes afb2c27, “wayland/lock: guard against
reentrancy during surface creation.” This prevents the known fatal path
when acquisition fails or re-enters during surface creation. It does not
clear the session-lock manager's active pointer when a live lock object is
destroyed without `unlock()`, so the orphaned-lock lifecycle remains
unresolved upstream. Hornero requires Quickshell 0.3.2 or later and retains
the single-locker policy; the version floor is a partial containment, not a
claim that cross-locker recovery works.

## Recovery

There are two different failure states:

- If Quickshell exits but Hyprland does **not** show its crashed-lockscreen
  fallback, restart the shell with `horneroctl shell restart --yes`.
- If Hyprland shows the **“lockscreen app died”** fallback, restarting
  Quickshell alone cannot repair the compositor-owned session-lock state.
  Keep the session locked and recover from another TTY after authenticating
  locally. Do not use `hl.clear_crashed_lockscreen()` when the session must
  remain protected: Hyprland implements it with `forceUnlock()`, so it clears
  the crashed lock instead of restoring an authentication prompt ([0.56.2
  implementation](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsToplevel.cpp#L337-L349)).

Hyprland's recovery command depends on its config manager. With the legacy
Hyprlang config, allow a lock restore and immediately start the lockscreen
again:

```sh
hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'
hyprctl --instance 0 'dispatch exec hyprlock'
```

The setting above is applied at runtime. If old `hyprlock` processes are
still blocking reacquisition, follow Hyprland's recovery guidance from the
authenticated TTY to stop those stale processes and relaunch the lock
immediately. Lua-managed
Hyprland configs require the `eval` form instead; do not mix the two command
forms. See the upstream [crashed-lockscreen recovery report](https://github.com/hyprwm/Hyprland/issues/8847)
and [Lua-config recovery discussion](https://github.com/hyprwm/Hyprland/discussions/14762).

Never run hyprlock and the shell lock in the same session on purpose, and
never re-request a lock while one is engaged.
