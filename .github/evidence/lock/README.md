# lock — Signal Bezel evidence (W4c, agent B)

- `after-*-offscreen-*.png` — this branch, rendered by an **offscreen** Qt
  harness (offscreen platform + llvmpipe, the real lock `Content` and
  shell services/Signal roles, a stub `Pam` object, a private session bus
  and isolated XDG dirs). They are not captures of a real session lock:
  `WlSessionLock`/`WlSessionLockSurface` need a compositor, so the surface
  background (wallpaper blur) is represented by a gradient plus the same
  `ground` scrim as `LockSurface.qml`. Nothing touched the live session.
- `idle` = empty field; `wrong-password` = PAM `fail` state with a typed
  buffer. Themes: `night` = hornero-signal-night, `day` =
  hornero-signal-day, `hc` = Signal High Contrast.
- The lock `Pam` flow, `lock.unlocking` and the session lock itself are
  unchanged (`tests/test_lock_*`).
