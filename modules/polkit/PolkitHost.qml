pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Polkit
import QtQuick

// Additive native polkit agent (shell#352, PR-1).
// Registers Quickshell's PolkitAgent for the session. If another
// session agent already holds the registration, isRegistered stays
// false: log once and no-op (the dialog never shows). This slice does
// not remove or replace any external agent.
Scope {
    id: root

    property bool _unregisteredLogged: false

    function _warnIfUnregistered(): void {
        if (!polkitAgent.isRegistered && !root._unregisteredLogged) {
            root._unregisteredLogged = true;
            console.warn("polkit: native agent not registered (another session agent may hold the registration); native dialog disabled");
        }
    }

    PolkitAgent {
        id: polkitAgent

        onIsRegisteredChanged: {
            if (!polkitAgent.isRegistered)
                root._warnIfUnregistered();
        }
    }

    // isRegistered may simply stay false (no change signal) when the
    // registration is already held elsewhere, so check once shortly
    // after startup as well. The guard above keeps this to one line.
    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: root._warnIfUnregistered()
    }

    PolkitDialog {
        agent: polkitAgent
    }
}
