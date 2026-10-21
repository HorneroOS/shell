import qs.modules.lock
import Quickshell
import QtQuick

// AT-SPI probe harness for the lock content (Center + InputField).
// Run via tests/atspi/run-lock-probe.sh, which stages a scratch dir
// where modules/lock/Pam.qml is the inert stub in lockstub/ — the
// real Pam requires a WlSessionLock and must never engage during a
// probe. Expected tree entries: text "Password", push button
// "Unlock" (docs/a11y-audit-2026-10-21.md).
ShellRoot {
    QtObject {
        id: stubLock

        property var screen: null
        property bool unlocking: false
        property Pam pam: Pam {}
    }

    PanelWindow {
        anchors {
            top: true
            left: true
        }
        implicitWidth: 900
        implicitHeight: 700
        color: "#14141f"

        Center {
            anchors.centerIn: parent
            lock: stubLock
        }
    }

    Timer {
        interval: 240000
        running: true
        onTriggered: Qt.quit()
    }
}
