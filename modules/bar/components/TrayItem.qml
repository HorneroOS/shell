pragma ComponentBehavior: Bound

import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell.Services.SystemTray
import QtQuick

MouseArea {
    id: root

    required property SystemTrayItem modelData
    // Region tone (Tray.qml): tray icons take the ink of their region.
    property var tone: ClearInk.neutral

    Accessible.role: Accessible.Button
    Accessible.name: root.modelData.title || root.modelData.id

    Tooltip {
        target: root
        text: root.modelData.tooltipTitle || root.modelData.title || root.modelData.id
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: Density.iconPx
    implicitHeight: Density.iconPx

    onClicked: event => {
        if (event.button === Qt.LeftButton)
            modelData.activate();
        else
            modelData.secondaryActivate();
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        implicitSize: Density.iconPx
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: root.tone.ink
        layer.enabled: Config.bar.tray.recolour
    }
}
