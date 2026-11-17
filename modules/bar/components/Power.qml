import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property PersistentProperties visibilities

    implicitWidth: icon.implicitHeight + Appearance.padding.small * 2
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

        radius: Appearance.rounding.small

        function onClicked(): void {
            root.visibilities.session = !root.visibilities.session;
        }
    }

    Glyph {
        id: icon

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1

        name: "power"
        color: root.tone.alert
        font.bold: true
        font.pointSize: Appearance.font.size.normal
    }
}
