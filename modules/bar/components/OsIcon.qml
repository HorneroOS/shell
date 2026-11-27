import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    Tooltip {
        target: root
        text: qsTr("Open launcher")
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Open launcher")

        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    ColouredIcon {
        anchors.centerIn: parent
        // The Hornero mark (signal amber, the one permanent accent) on every
        // host; `bar.mark: "distro"` opts into the base distro logo, in ink.
        source: Config.bar.mark === "distro" ? SysInfo.osLogo : Qt.resolvedUrl(`${Quickshell.shellDir}/assets/mark.svg`)
        implicitSize: Density.iconPx + 2
        colour: Config.bar.mark === "distro" ? root.tone.ink : Signal.palette.signal
    }

    implicitWidth: Density.iconPx + 2
    implicitHeight: Density.iconPx + 2
}
