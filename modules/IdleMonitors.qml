pragma ComponentBehavior: Bound

import "lock"
import qs.config
import qs.services
import Hornero.Internal
import Quickshell
import Quickshell.Wayland
import QtQml

Scope {
    id: root

    required property Lock lock
    readonly property bool enabled: !Config.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)

    // Lock-only mode (shell#257): the standalone lock process runs its
    // own IdleMonitors with this true so idle/logind lock requests reach
    // the lock owner, while dpms/dispatch actions stay with the main
    // shell's monitors (never executed twice).
    property bool lockOnly: false
    property bool pendingSleepLock: false

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (lockOnly && action !== "lock")
            return;

        if (action === "lock")
            lock.requestLock();
        else if (action === "unlock") {
            console.warn("IdleMonitors: ignoring unauthenticated unlock idle action");
            return;
        } else if (action === "dpms off")
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
        id: logindManager

        onAboutToSleep: {
            if (Config.general.idle.lockBeforeSleep) {
                if (root.lock.lock.secure) {
                    logindManager.releaseSleepInhibitor();
                } else {
                    root.pendingSleepLock = true;
                    root.lock.requestLock();
                }
            } else {
                logindManager.releaseSleepInhibitor();
            }
        }
        onResumed: root.pendingSleepLock = false
        onLockRequested: root.lock.requestLock()
        onUnlockRequested: root.lock.lock.unlock()
    }

    Connections {
        target: root.lock.lock

        function onSecureChanged(): void {
            if (root.lock.lock.secure && root.pendingSleepLock) {
                root.pendingSleepLock = false;
                logindManager.releaseSleepInhibitor();
            }
        }
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
