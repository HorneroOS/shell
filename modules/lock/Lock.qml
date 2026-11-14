pragma ComponentBehavior: Bound

import qs.components.misc
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    property alias lock: lock

    // Single acquisition point for the in-shell session lock (shell#24).
    // Before quickshell 0.3.2, a failed acquisition could hit qFatal during
    // surface creation (upstream quickshell#1054; afb2c27 is in 0.3.2).
    // That guard does not repair a previously orphaned compositor lock or
    // its stale manager state.
    // Policy, see docs/LOCKING.md:
    //   - no-op while already locked or while a request is in flight;
    //   - refuse while the foreign hyprlock backend holds the session;
    //   - fail OPEN when the probe itself errors (a missing/broken pidof
    //     must never wedge the lock shut).
    property bool lockRequestPending: false

    // Lock ownership (shell#257): exactly one process may acquire the
    // session lock. The main shell sets this false when the standalone
    // lock process (lock.qml + hornero-lock.service) is enabled via
    // HORNERO_EXTERNAL_LOCK=1, making its requestLock() a no-op; the
    // lock process leaves it true. Default true = current behaviour.
    property bool lockOwner: true

    function requestLock(): void {
        if (!lockOwner) {
            console.warn("lock: not the lock owner, ignoring request (external lock process owns it)");
            return;
        }
        if (lock.locked || lockRequestPending) {
            console.warn("lock: redundant request ignored (already locked or in flight)");
            return;
        }
        lockRequestPending = true;
        foreignLockerProbe.running = true;
    }

    Process {
        id: foreignLockerProbe

        command: ["pidof", "-x", "hyprlock"]

        onExited: (exitCode, exitStatus) => {
            lockRequestPending = false;
            if (exitStatus !== 0) {
                console.warn("lock: locker probe failed, proceeding (fail-open)");
            } else if (exitCode === 0) {
                console.warn("lock: hyprlock is running, refusing shell lock (single-locker policy)");
                return;
            }
            // Re-check: the lock may have engaged while the probe ran.
            if (!lock.locked)
                lock.locked = true;
        }
    }

    WlSessionLock {
        id: lock

        signal unlock

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    CustomShortcut {
        name: "lock"
        description: "Lock the current session"
        onPressed: requestLock()
    }

    // No shortcut or IPC unlock path: unlocking requires PAM success
    // inside Pam.qml (passwd/fprint onCompleted -> lock.unlock()).
    // Quickshell IPC is reachable by any same-user process, so an
    // `unlock` IPC/shortcut would be unauthenticated unlock (shell#257).
    IpcHandler {
        target: "lock"

        function lock(): void {
            requestLock();
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
