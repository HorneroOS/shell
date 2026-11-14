//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/companion"
import "modules/plugins"
import "modules/lock"
import "modules/polkit"
import "modules/welcome"
import Quickshell

ShellRoot {
    // External lock process (shell#257, opt-in): with
    // HORNERO_EXTERNAL_LOCK=1 the standalone lock.qml instance owns
    // session-lock acquisition and this shell's requestLock() no-ops.
    // Unset (default) keeps the in-shell lock exactly as before.
    readonly property bool externalLock: ["1", "true"].includes((Quickshell.env("HORNERO_EXTERNAL_LOCK") ?? "").toLowerCase())

    Background {}
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock

        lockOwner: !externalLock
    }
    PolkitHost {}

    Shortcuts {}
    CompanionHost {
        lock: lock.lock
    }
    PluginHost {}
    PluginLauncherHost {}
    Startup {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
