import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick

StyledRect {
    id: root

    required property ShellScreen screen
    required property Session session

    implicitHeight: text.implicitHeight + Appearance.padding.normal
    color: Colours.tPalette.m3surfaceContainer

    // Brand tile (same treatment as Welcome): the graphite logo
    // needs its paper chip to read on the title bar.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Appearance.padding.normal
        width: 30
        height: 30
        radius: 8
        color: "#fffdf7"

        Image {
            anchors.centerIn: parent
            width: 23
            height: 23
            source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)
            fillMode: Image.PreserveAspectFit
            Accessible.name: qsTr("Hornero logo")
        }
    }

    StyledText {
        id: text

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        text: qsTr("Hornero Settings - %1").arg(root.session.activeTitle)
        font.capitalization: Font.Capitalize
        font.pointSize: Appearance.font.size.larger
        font.weight: 500
    }

    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        implicitWidth: implicitHeight
        implicitHeight: closeIcon.implicitHeight + Appearance.padding.small

        Interactive {
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Close Settings window")
            Accessible.description: qsTr("Close the floating Settings window")

            radius: Appearance.rounding.full

            function onClicked(): void {
                WindowFactory.closeWindow(QsWindow.window);
            }
        }

        MaterialIcon {
            id: closeIcon

            anchors.centerIn: parent
            text: "close"
        }
    }
}
