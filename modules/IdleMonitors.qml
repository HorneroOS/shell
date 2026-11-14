pragma ComponentBehavior: Bound

import "lock"
import qs.config
import qs.services
import Hornero.Internal
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property Lock lock
    readonly property bool enabled: !Config.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)

    // Lock-only mode (shell#257): the standalone lock process runs its
    // own IdleMonitors with this true so idle/logind lock requests reach
    // the lock owner, while dpms/dispatch actions stay with the main
    // shell's monitors (never executed twice).
    property bool lockOnly: false

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (lockOnly && action !== "lock" && action !== "unlock")
            return;

        if (action === "lock")
            lock.requestLock();
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (action === "dpms off")
            Compositor.setMonitorsPowered(false);
        else if (action === "dpms on")
            Compositor.setMonitorsPowered(true);
        else if (typeof action === "string") {
            if (Compositor.isHyprland)
                Hypr.dispatch(action);
        } else {
            Quickshell.execDetached(action);
        }
    }

    LogindManager {
        onAboutToSleep: {
            if (Config.general.idle.lockBeforeSleep)
                root.lock.requestLock();
        }
        onLockRequested: root.lock.requestLock()
        onUnlockRequested: root.lock.lock.unlock()
    }

    Variants {
        model: Config.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
