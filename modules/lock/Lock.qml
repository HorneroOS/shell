pragma ComponentBehavior: Bound

import qs.components.misc
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    property alias lock: lock

    // Single acquisition point for the in-shell session lock (shell#24).
    // A redundant `locked = true` write is the reentrant path that kills
    // quickshell (upstream quickshell#1054, fixed on master by afb2c27 but
    // in no release yet), and a fatal Wayland protocol error is
    // uncatchable from QML — so acquisition must be prevented, never
    // retried. Policy, see docs/LOCKING.md:
    //   - no-op while already locked or while a request is in flight;
    //   - refuse while the foreign hyprlock backend holds the session;
    //   - fail OPEN when the probe itself errors (a missing/broken pidof
    //     must never wedge the lock shut).
    property bool lockRequestPending: false

    function requestLock(): void {
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

    CustomShortcut {
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            requestLock();
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }
    }
}
