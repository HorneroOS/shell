import Quickshell
import QtQuick

// Inert Pam stub for the AT-SPI lock harness only (see
// run-lock-probe.sh). It replaces modules/lock/Pam.qml inside a
// scratch copy so the lock content can render without a real
// WlSessionLock: it never authenticates and never locks anything.
Scope {
    id: root

    property string lockMessage: ""
    property string state: ""
    property string fprintState: ""
    property string buffer: ""

    signal flashMsg

    function handleKey(event: KeyEvent): void {
    }

    property QtObject passwd: QtObject {
        property bool active: false
        property string message: ""

        function start(): void {
        }
    }
    property QtObject fprint: QtObject {
        property bool active: false
        property int tries: 0
        property string message: ""
    }
}
