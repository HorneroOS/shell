import qs.modules.controlcenter
import qs.modules.controlcenter.appearance
import Quickshell
import QtQuick

// Runtime AT-SPI coverage for the real Appearance pane and its shipped
// option delegates. run-appearance-probe.sh supplies isolated config/data
// directories and a read-only horneroctl fixture; this harness never applies
// an appearance or touches the user's session configuration.
ShellRoot {
    id: appRoot

    Session {
        id: session
        root: appRoot
        active: "appearance"
    }

    PanelWindow {
        anchors {
            top: true
            left: true
        }
        implicitWidth: 1180
        implicitHeight: 820
        color: "#14141f"

        AppearancePane {
            id: appearancePane
            anchors.fill: parent
            session: session

            Component.onCompleted: Qt.callLater(() => appearancePane.setAllSections(true))
        }
    }

    Timer {
        interval: 90000
        running: true
        onTriggered: Qt.quit()
    }
}
