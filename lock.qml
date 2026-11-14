//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import "modules"
import "modules/lock"
import Quickshell

// Standalone lock process (shell#257): a lock-only quickshell instance
// (`qs --path <conf>/lock.qml`, supervised by hornero-lock.service) so a
// main-shell crash or restart can no longer take the session lock surface
// down with it. It hosts only the Lock module plus lock-only idle/logind
// monitors; the desktop (bar, drawers, plugins) stays in shell.qml.
//
// Opt-in and staged: the main shell keeps owning the lock by default.
// Enable this process (and set HORNERO_EXTERNAL_LOCK=1 for the main shell)
// only as a pair — Lock.lockOwner makes the non-owner's requestLock() a
// no-op, so the two never fight over acquisition (single-locker policy,
// docs/LOCKING.md). Unlock stays PAM-only inside this process (shell#404).
ShellRoot {
    Lock {
        id: lock

        lockOwner: true
    }

    IdleMonitors {
        lock: lock
        lockOnly: true
    }
}
