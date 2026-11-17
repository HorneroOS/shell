import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import Quickshell
import QtQuick

StyledRect {
    id: root

    required property ShellScreen screen
    required property Session session

    implicitHeight: 30 + Appearance.padding.normal + 1
    color: Signal.tPalette.panel

    // Brand tile (same treatment as Welcome): the graphite logo
    // needs its paper chip to read on the title bar.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Appearance.padding.normal
        width: 30
        height: 30
        radius: 8
        color: Signal.palette.inverse

        Image {
            anchors.centerIn: parent
            width: 23
            height: 23
            source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/logo.svg`)
            fillMode: Image.PreserveAspectFit
            Accessible.name: qsTr("Hornero logo")
        }
    }

    // Eyebrow trail in the Signal channel language: SETTINGS · PAGE.
    // The compositor window title (WindowFactory) stays "Hornero Settings -
    // Page" for window matching; this bar shows the trail only.
    Instruments.Eyebrow {
        id: text

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal * 2 + 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1

        label: `${qsTr("Settings")} · ${root.session.activeTitle}`
        Accessible.ignored: false
        Accessible.role: Accessible.Heading
        Accessible.name: qsTr("Settings, %1").arg(root.session.activeTitle)
    }

    Hairline {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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

            radius: Appearance.rounding.small
            activeFocusOnTab: true

            function onClicked(): void {
                WindowFactory.closeWindow(QsWindow.window);
            }
        }

        Glyph {
            id: closeIcon

            anchors.centerIn: parent
            name: "x"
        }
    }
}
